
module Vehicle.Compile.Type
  ( TypeCheckable(..)
  ) where

import Control.Monad.Except (MonadError(..))
import Control.Monad (forM, when, unless)
import Data.List (partition)
import Data.List.NonEmpty (NonEmpty(..))

import Vehicle.Compile.Prelude
import Vehicle.Compile.Error
import Vehicle.Language.Print
import Vehicle.Compile.Type.Constraint
import Vehicle.Compile.Type.ConstraintSolver.TypeClass
import Vehicle.Compile.Type.ConstraintSolver.TypeClassDefaults
import Vehicle.Compile.Type.ConstraintSolver.Unification
import Vehicle.Compile.Type.Meta
import Vehicle.Compile.Type.MetaSet qualified as MetaSet
import Vehicle.Compile.Type.Auxiliary
import Vehicle.Compile.Type.Bidirectional
import Vehicle.Compile.Type.WeakHeadNormalForm
import Vehicle.Compile.Type.VariableContext
import Vehicle.Compile.Type.Resource
import Vehicle.Compile.Type.Generalise
import Vehicle.Compile.Type.Irrelevance

-------------------------------------------------------------------------------
-- Algorithm

class TypeCheckable a b where
  typeCheck :: MonadCompile m => a -> m b

instance TypeCheckable UncheckedProg CheckedProg where
  typeCheck prog1 =
    logCompilerPass MinDetail "type checking" $ runTCM $ do
    prog2 <- typeCheckProg prog1
    prog3 <- postProcess prog2
    logDebug MaxDetail $ prettyFriendlyDBClosed prog3
    return prog3


instance TypeCheckable UncheckedExpr CheckedExpr where
  typeCheck expr1 = runTCM $ do
    expr2 <- insertHolesForAuxiliaryAnnotations expr1
    (expr3, _exprType) <- inferExpr expr2
    solveConstraints Nothing
    expr4 <- postProcess expr3
    checkAllUnknownsSolved
    return expr4

postProcess :: ( TCM m
               , MetaSubstitutable a
               , WHNFable a
               , RemoveIrrelevantCode a
               )
            => a -> m a
postProcess x = do
  metaFreeExpr <- substMetas x
  normExpr     <- convertImplicitArgsToWHNF metaFreeExpr
  finalExpr    <- removeIrrelevantCode normExpr
  return finalExpr

-------------------------------------------------------------------------------
-- Type-class for things that can be type-checked

typeCheckProg :: TCM m => UncheckedProg -> m CheckedProg
typeCheckProg (Main ds) = Main <$> typeCheckDecls ds

typeCheckDecls :: TCM m => [UncheckedDecl] -> m [CheckedDecl]
typeCheckDecls [] = return []
typeCheckDecls (d : ds) = do
  -- First insert any missing auxiliary arguments into the decl
  d' <- insertHolesForAuxiliaryAnnotations d
  checkedDecl  <- typeCheckDecl d'
  checkedDecls <- addDeclToCtx checkedDecl $ typeCheckDecls ds
  return $ checkedDecl : checkedDecls

typeCheckDecl :: TCM m => UncheckedDecl -> m CheckedDecl
typeCheckDecl decl = logCompilerPass MinDetail ("declaration" <+> identDoc) $ do
  -- First run a bidirectional pass over the type of the declaration
  checkedType <- logCompilerPass MidDetail (passDoc <+> "type of" <+> identDoc) $ do
    let declType = typeOf decl
    (checkedType, typeOfType) <- inferExpr declType
    assertIsType (provenanceOf decl) typeOfType
    return checkedType

  result <- case decl of
    DefResource p r _ _ -> do
      let checkedDecl = DefResource p r ident checkedType
      solveConstraints (Just checkedDecl)
      substCheckedType <- substMetas checkedType

      -- Add extra constraints from the resource type. Need to have called
      -- solve constraints beforehand in order to allow for normalisation,
      -- but really only need to have solved type-class constraints.
      updatedCheckedType <- checkResourceType r (ident, p) substCheckedType
      let updatedCheckedDecl = DefResource p r ident updatedCheckedType
      solveConstraints (Just updatedCheckedDecl)

      substDecl <- substMetas updatedCheckedDecl
      logUnsolvedUnknowns (Just substDecl) Nothing

      finalDecl <- generaliseOverUnsolvedMetaVariables substDecl
      return finalDecl

    DefPostulate p _ _ -> do
      return $ DefPostulate p ident checkedType

    DefFunction p propertyInfo _ _ body -> do
      checkedBody <- logCompilerPass MidDetail (passDoc <+> "body of" <+> identDoc) $ do
        checkExpr checkedType body
      let checkedDecl = DefFunction p propertyInfo ident checkedType checkedBody

      solveConstraints (Just checkedDecl)

      substDecl <- substMetas checkedDecl
      logUnsolvedUnknowns (Just substDecl) Nothing

      checkedDecl2 <- generaliseOverUnsolvedTypeClassConstraints substDecl
      checkedDecl3 <- generaliseOverUnsolvedMetaVariables checkedDecl2
      finalDecl    <- updatePropertyInfo checkedDecl3
      return finalDecl

  checkAllUnknownsSolved
  logCompilerPassOutput $ prettyFriendlyDBClosed result
  return result

  where
    ident = identifierOf decl
    identDoc = squotes (pretty ident)
    passDoc = "bidirectional pass over"

assertIsType :: TCM m => Provenance -> CheckedExpr -> m ()
-- This is a bit of a hack to get around having to have a solver for universe
-- levels. As type definitions will always have an annotated Type 0 inserted
-- by delaboration, we can match on it here. Anything else will be unified
-- with type 0.
assertIsType _ (TypeUniverse _ _) = return ()
assertIsType p t        = do
  ctx <- getVariableCtx
  let typ = TypeUniverse (inserted (provenanceOf t)) 0
  addUnificationConstraint TypeGroup p ctx t typ
  return ()

-------------------------------------------------------------------------------
-- Constraint solving

-- | Tries to solve constraints. Passes in the type of the current declaration
-- being checked, as metas are handled different according to whether they
-- occur in the type or not.
solveConstraints :: MonadMeta m => Maybe CheckedDecl -> m ()
solveConstraints decl = logCompilerPass MinDetail "constraint solving" $ do
  loopOverConstraints 1 decl

loopOverConstraints :: MonadMeta m
                    => Int
                    -> Maybe CheckedDecl
                    -> m ()
loopOverConstraints loopNumber decl = do
  unsolvedConstraints <- getUnsolvedConstraints
  metasSolvedLastLoop <- getSolvedMetas
  clearSolvedMetas

  unless (null unsolvedConstraints) $ do
    let isUnblocked = isUnblockedBy metasSolvedLastLoop
    let (unblockedConstraints, blockedConstraints) = partition isUnblocked unsolvedConstraints

    if null unblockedConstraints then do
      -- If no constraints are unblocked then try generating new constraints using defaults.
      successfullyGeneratedDefault <- addNewConstraintUsingDefaults decl
      when successfullyGeneratedDefault $ do
        -- If new constraints generated then continue solving.
        loopOverConstraints loopNumber decl

    else do
      -- If we have made useful progress then start a new pass

      -- TODO try to solve only either new constraints or those that contain
      -- blocking metas that were solved last iteration.
      updatedDecl <- logCompilerPass MaxDetail
        ("constraint solving pass" <+> pretty loopNumber) $ do

        updatedDecl <- traverse substMetas decl
        logUnsolvedUnknowns updatedDecl (Just metasSolvedLastLoop)

        setConstraints blockedConstraints
        mconcat `fmap` traverse solveConstraint unblockedConstraints

        substMetasThroughCtx
        newSubstitution <- getMetaSubstitution
        logDebug MaxDetail $ "current-solution:" <+>
          prettyVerbose newSubstitution <> "\n"

        return updatedDecl

      loopOverConstraints (loopNumber + 1) updatedDecl

-- | Tries to solve a constraint deterministically.
solveConstraint :: MonadMeta m
                => Constraint
                -> m ()
solveConstraint unnormConstraint = do
  constraint <- whnfConstraintWithMetas unnormConstraint

  logCompilerSection MaxDetail ("trying" <+> prettyVerbose constraint) $ do
    result <- case constraint of
      UC ctx c -> solveUnificationConstraint ctx c
      TC ctx c -> solveTypeClassConstraint   ctx c

    case result of
      Progress newConstraints -> addConstraints newConstraints
      Stuck metas -> do
        let blockedConstraint = blockConstraintOn constraint metas
        addConstraints [blockedConstraint]

-- | Tries to add new unification constraints using default values.
addNewConstraintUsingDefaults :: MonadMeta m
                              => Maybe CheckedDecl
                              -> m Bool
addNewConstraintUsingDefaults maybeDecl = do
  logDebug MaxDetail $ "Temporarily stuck" <> line

  logCompilerPass MidDetail
    "trying to generate a new constraint using type-classes defaults" $ do

    -- Calculate the set of candidate constraints
    candidateConstraints <- getDefaultCandidates maybeDecl
    logDebug MaxDetail $ "Candidate type-class constraints:" <> line <>
      indent 2 (prettySimple candidateConstraints) <> line

    result <- generateConstraintUsingDefaults candidateConstraints
    case result of
      Nothing            -> return False
      Just newConstraint -> do
        addConstraints [newConstraint]
        return True

getDefaultCandidates :: MonadMeta m => Maybe CheckedDecl -> m [Constraint]
getDefaultCandidates maybeDecl = do
  unsolvedConstraints <- filter isNonAuxiliaryTypeClassConstraint <$> getUnsolvedConstraints
  case maybeDecl of
    Nothing   -> return unsolvedConstraints
    Just decl -> do
      declType <- substMetas (typeOf decl)

      -- We only want to generate default solutions for constraints
      -- that *don't* appear in the type of the declaration, as those will be
      -- quantified over later.
      typeMetas <- getMetasLinkedToMetasIn declType isTypeUniverse

      unsolvedMetasInTypeDoc <- prettyMetas typeMetas
      logDebug MaxDetail $
        "Metas transitively related to type-signature:" <+> unsolvedMetasInTypeDoc

      return $ flip filter unsolvedConstraints $ \c ->
        MetaSet.disjoint (metasIn c) typeMetas

-------------------------------------------------------------------------------
-- Property information extraction

updatePropertyInfo :: MonadCompile m => CheckedDecl -> m CheckedDecl
updatePropertyInfo = \case
  r@DefResource{}       -> return r
  r@DefPostulate{}      -> return r
  r@(DefFunction p maybePropertyInfo ident t e) -> case maybePropertyInfo of
    Nothing -> return r
    Just _  -> do
      propertyInfo@(PropertyInfo linearity polarity) <- getPropertyInfo (ident, p) t
      logDebug MinDetail $
        "Identified" <+> squotes (pretty ident) <+> "as a property of type:" <+>
          pretty linearity <+> pretty polarity
      return $ DefFunction p (Just propertyInfo) ident t e

getPropertyInfo :: MonadCompile m => DeclProvenance -> CheckedType -> m PropertyInfo
getPropertyInfo decl = \case
  (AnnBoolType _ (Builtin _ (Linearity lin)) (Builtin _ (Polarity pol))) -> return $ PropertyInfo lin pol
  (VectorType _ tElem _) -> getPropertyInfo decl tElem
  (TensorType _ tElem _) -> getPropertyInfo decl tElem
  otherType              -> throwError $ PropertyTypeUnsupported decl otherType

-------------------------------------------------------------------------------
-- Unsolved constraint checks

checkAllUnknownsSolved :: MonadMeta m => m ()
checkAllUnknownsSolved = do
  -- First check all user constraints (i.e. unification and type-class
  -- constraints) are solved.
  checkAllConstraintsSolved
  -- Then check all meta-variables have been solved.
  checkAllMetasSolved
  -- Then clear the meta-ctx
  clearMetaCtx

checkAllConstraintsSolved :: MonadMeta m => m ()
checkAllConstraintsSolved = do
  constraints <- getUnsolvedConstraints
  case constraints of
    []       -> return ()
    (c : cs) -> throwError $ UnsolvedConstraints (c :| cs)

checkAllMetasSolved :: MonadMeta m => m ()
checkAllMetasSolved = do
  unsolvedMetas <- getUnsolvedMetas
  case MetaSet.toList unsolvedMetas of
    []     -> return ()
    m : ms -> do
      metasAndOrigins <- forM (m :| ms) (\meta -> do
        origin <- getMetaProvenance meta
        return (meta, origin))
      throwError $ UnsolvedMetas metasAndOrigins

logUnsolvedUnknowns :: MonadMeta m => Maybe CheckedDecl -> Maybe MetaSet -> m ()
logUnsolvedUnknowns maybeDecl maybeSolvedMetas = do
  unsolvedMetas    <- getUnsolvedMetas
  unsolvedMetasDoc <- prettyMetas unsolvedMetas
  logDebug MaxDetail $ "unsolved-metas:" <> line <>
    indent 2 unsolvedMetasDoc <> line

  unsolvedConstraints <- getUnsolvedConstraints
  case maybeSolvedMetas of
    Nothing ->
      logDebug MaxDetail $ "unsolved-constraints:" <> line <>
        indent 2 (prettyVerbose unsolvedConstraints) <> line
    Just solvedMetas -> do
      let isUnblocked = isUnblockedBy solvedMetas
      let (unblockedConstraints, blockedConstraints) = partition isUnblocked unsolvedConstraints
      logDebug MaxDetail $ "unsolved-blocked-constraints:" <> line <>
        indent 2 (prettyVerbose blockedConstraints) <> line
      logDebug MaxDetail $ "unsolved-unblocked-constraints:" <> line <>
        indent 2 (prettyVerbose unblockedConstraints) <> line

  case maybeDecl of
    Nothing   -> return ()
    Just decl -> logDebug MaxDetail $ "current-decl:" <> line <>
      indent 2 (prettyVerbose decl) <> line