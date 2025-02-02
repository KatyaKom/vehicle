{-# OPTIONS_GHC -Wno-orphans #-}
{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}

{-# HLINT ignore "Use <|>" #-}

module Vehicle.Compile.Normalise.NBE
  ( whnf,
    evalBuiltin,
    evalApp,
    eval,
    liftEnvOverBinder,
    forceExpr,
  )
where

import Control.Monad.Reader (MonadReader (..), ReaderT (..), asks)
import Data.Foldable (foldrM)
import Data.List.NonEmpty as NonEmpty (toList)
import Data.Map qualified as Map (lookup)
import Data.Maybe (isJust)
import Vehicle.Compile.Error
import Vehicle.Compile.Prelude
import Vehicle.Compile.Type.Meta (MetaSet)
import Vehicle.Compile.Type.Meta.Map qualified as MetaMap
import Vehicle.Compile.Type.Meta.Set qualified as MetaSet
import Vehicle.Compile.Type.VariableContext (DeclSubstitution, MetaSubstitution)
import Vehicle.Expr.DeBruijn
import Vehicle.Expr.Normalised

whnf :: MonadCompile m => DBLevel -> DeclSubstitution -> MetaSubstitution -> CheckedExpr -> m NormExpr
whnf boundCtxSize declCtx metaSubst e = do
  let env = [VBoundVar mempty i [] | i <- reverse [0 .. boundCtxSize - 1]]
  runReaderT (eval env e) (declCtx, metaSubst)

-----------------------------------------------------------------------------
-- Evaluation

type MonadNorm m =
  ( MonadCompile m,
    MonadReader (DeclSubstitution, MetaSubstitution) m
  )

-- TODO change to return a tuple of NF and WHNF?
eval :: MonadNorm m => Env -> CheckedExpr -> m NormExpr
eval env expr = do
  showEntry env expr
  result <- case expr of
    Hole {} -> resolutionError currentPass "Hole"
    Meta p m -> return $ VMeta p m []
    Universe p u -> return $ VUniverse p u
    Builtin p b -> return $ VBuiltin p b []
    Literal p l -> return $ VLiteral p l
    Ann _ e _ -> eval env e
    LVec p xs -> VLVec p <$> traverse (eval env) xs <*> pure []
    Lam p binder body -> do
      binder' <- evalBinder env binder
      return $ VLam p binder' env body
    Pi p binder body ->
      VPi p <$> evalBinder env binder <*> eval (liftEnvOverBinder p env) body
    Var p v -> case v of
      Bound i -> case lookupVar env i of
        Just value -> return value
        Nothing ->
          compilerDeveloperError $
            "Environment of size"
              <+> pretty (length env)
              <+> "in which NBE is being performed"
              <+> "is smaller than the found DB index"
              <+> pretty i
      Free ident -> do
        declExpr <- asks (Map.lookup ident . fst)
        return $ case declExpr of
          Just x -> x
          Nothing -> VFreeVar p ident []
    Let _ bound _binder body -> do
      boundNormExpr <- eval env bound
      eval (boundNormExpr : env) body
    App _ fun args -> do
      fun' <- eval env fun
      args' <- traverse (traverse (eval env)) args
      evalApp fun' (NonEmpty.toList args')

  showExit result
  return result

evalBinder :: MonadNorm m => Env -> CheckedBinder -> m NormBinder
evalBinder env = traverse (eval env)

evalApp :: MonadNorm m => NormExpr -> [GenericArg NormExpr] -> m NormExpr
evalApp fun [] = return fun
evalApp fun (arg : args) = case fun of
  VMeta p v spine -> return $ VMeta p v (spine <> (arg : args))
  VFreeVar p v spine -> return $ VFreeVar p v (spine <> (arg : args))
  VBoundVar p v spine -> return $ VBoundVar p v (spine <> (arg : args))
  VLVec p xs spine -> return $ VLVec p xs (spine <> (arg : args))
  VLam _ _binder env body -> do
    body' <- eval (argExpr arg : env) body
    case args of
      [] -> return body'
      (a : as) -> evalApp body' (a : as)
  VBuiltin p b spine -> evalBuiltin p b (spine <> (arg : args))
  VUniverse {} -> unexpectedExprError currentPass "VUniverse"
  VPi {} -> unexpectedExprError currentPass "VPi"
  VLiteral {} -> unexpectedExprError currentPass "VLiteral"

-- Separate builtins from syntactic sugar
--
-- Pass in the right number of arguments ensuring all literals

evalBuiltin ::
  MonadNorm m =>
  Provenance ->
  Builtin ->
  [GenericArg NormExpr] ->
  m NormExpr
evalBuiltin p b args = case b of
  -- TODO rearrange builtin constructors so we don't have to do this.
  Constructor {} -> return $ VBuiltin p b args
  Not -> evalNot p args
  And -> evalAnd p args
  Or -> evalOr p args
  FromNat v dom -> case dom of
    FromNatToIndex -> evalFromNatToIndex v p args
    FromNatToNat -> evalFromNatToNat v p args
    FromNatToInt -> evalFromNatToInt v p args
    FromNatToRat -> evalFromNatToRat v p args
  FromRat dom -> case dom of
    FromRatToRat -> evalFromRatToRat p args
  Neg dom -> case dom of
    NegInt -> evalNegInt p args
    NegRat -> evalNegRat p args
  Add dom -> case dom of
    AddNat -> evalAddNat p args
    AddInt -> evalAddInt p args
    AddRat -> evalAddRat p args
  Sub dom -> case dom of
    SubInt -> evalSubInt p args
    SubRat -> evalSubRat p args
  Mul dom -> case dom of
    MulNat -> evalMulNat p args
    MulInt -> evalMulInt p args
    MulRat -> evalMulRat p args
  Div dom -> case dom of
    DivRat -> evalDivRat p args
  Equals dom op -> case dom of
    EqIndex -> evalEqualityIndex op p args
    EqNat -> evalEqualityNat op p args
    EqInt -> evalEqualityInt op p args
    EqRat -> evalEqualityRat op p args
  Order dom op -> case dom of
    OrderIndex -> evalOrderIndex op p args
    OrderNat -> evalOrderNat op p args
    OrderInt -> evalOrderInt op p args
    OrderRat -> evalOrderRat op p args
  If -> evalIf p args
  At -> evalAt p args
  Fold dom -> case dom of
    FoldList -> evalFoldList p args
    FoldVector -> evalFoldVector p args
  -- Derived
  TypeClassOp op -> evalTypeClassOp p op args
  Implies -> evalImplies p args
  Map dom -> case dom of
    MapList -> evalMapList p args
    MapVector -> evalMapVec p args
  FromVec n dom -> case dom of
    FromVecToVec -> evalFromVecToVec n p args
    FromVecToList -> evalFromVecToList n p args
  Foreach ->
    evalForeach p args

type EvalBuiltin = forall m. MonadNorm m => Provenance -> [GenericArg NormExpr] -> m NormExpr

pattern VBool :: Bool -> GenericArg NormExpr
pattern VBool x <- ExplicitArg _ (VLiteral _ (LBool x))

pattern VIndex :: Int -> GenericArg NormExpr
pattern VIndex x <- ExplicitArg _ (VLiteral _ (LIndex _ x))

pattern VNat :: Int -> GenericArg NormExpr
pattern VNat x <- ExplicitArg _ (VLiteral _ (LNat x))

pattern VInt :: Int -> GenericArg NormExpr
pattern VInt x <- ExplicitArg _ (VLiteral _ (LInt x))

pattern VRat :: Rational -> GenericArg NormExpr
pattern VRat x <- ExplicitArg _ (VLiteral _ (LRat x))

-- TODO a lot of duplication in the below. Once we have separated out the
-- derived builtins we should be able to

evalNot :: EvalBuiltin
evalNot p = \case
  [VBool x] -> return $ VLiteral p (LBool (not x))
  args -> return $ VBuiltin p Not args

evalAnd :: EvalBuiltin
evalAnd p = \case
  [VBool x, VBool y] -> return $ VLiteral p (LBool (x && y))
  args -> return $ VBuiltin p And args

evalOr :: EvalBuiltin
evalOr p = \case
  [VBool x, VBool y] -> return $ VLiteral p (LBool (x && y))
  args -> return $ VBuiltin p Or args

evalNegInt :: EvalBuiltin
evalNegInt p = \case
  [VInt x] -> return $ VLiteral p (LInt (-x))
  args -> return $ VBuiltin p (Neg NegInt) args

evalNegRat :: EvalBuiltin
evalNegRat p = \case
  [VRat x] -> return $ VLiteral p (LRat (-x))
  args -> return $ VBuiltin p (Neg NegRat) args

evalAddNat :: EvalBuiltin
evalAddNat p = \case
  [VNat x, VNat y] -> return $ VLiteral p (LNat (x + y))
  args -> return $ VBuiltin p (Add AddNat) args

evalAddInt :: EvalBuiltin
evalAddInt p = \case
  [VInt x, VInt y] -> return $ VLiteral p (LInt (x + y))
  args -> return $ VBuiltin p (Add AddInt) args

evalAddRat :: EvalBuiltin
evalAddRat p = \case
  [VRat x, VRat y] -> return $ VLiteral p (LRat (x + y))
  args -> return $ VBuiltin p (Add AddRat) args

evalSubInt :: EvalBuiltin
evalSubInt p = \case
  [VInt x, VInt y] -> return $ VLiteral p (LInt (x - y))
  args -> return $ VBuiltin p (Sub SubInt) args

evalSubRat :: EvalBuiltin
evalSubRat p = \case
  [VRat x, VRat y] -> return $ VLiteral p (LRat (x - y))
  args -> return $ VBuiltin p (Sub SubRat) args

evalMulNat :: EvalBuiltin
evalMulNat p = \case
  [VNat x, VNat y] -> return $ VLiteral p (LNat (x * y))
  args -> return $ VBuiltin p (Mul MulNat) args

evalMulInt :: EvalBuiltin
evalMulInt p = \case
  [VInt x, VInt y] -> return $ VLiteral p (LInt (x * y))
  args -> return $ VBuiltin p (Mul MulInt) args

evalMulRat :: EvalBuiltin
evalMulRat p = \case
  [VRat x, VRat y] -> return $ VLiteral p (LRat (x * y))
  args -> return $ VBuiltin p (Mul MulRat) args

evalDivRat :: EvalBuiltin
evalDivRat p = \case
  [VRat x, VRat y] -> return $ VLiteral p (LRat (x * y))
  args -> return $ VBuiltin p (Div DivRat) args

evalOrderIndex :: OrderOp -> EvalBuiltin
evalOrderIndex op p = \case
  [VIndex x, VIndex y] -> return $ VLiteral p (LBool (orderOp op x y))
  args -> return $ VBuiltin p (Order OrderIndex op) args

evalOrderNat :: OrderOp -> EvalBuiltin
evalOrderNat op p = \case
  [VNat x, VNat y] -> return $ VLiteral p (LBool (orderOp op x y))
  args -> return $ VBuiltin p (Order OrderNat op) args

evalOrderInt :: OrderOp -> EvalBuiltin
evalOrderInt op p = \case
  [VInt x, VInt y] -> return $ VLiteral p (LBool (orderOp op x y))
  args -> return $ VBuiltin p (Order OrderInt op) args

evalOrderRat :: OrderOp -> EvalBuiltin
evalOrderRat op p = \case
  [VRat x, VRat y] -> return $ VLiteral p (LBool (orderOp op x y))
  args -> return $ VBuiltin p (Order OrderRat op) args

evalEqualityIndex :: EqualityOp -> EvalBuiltin
evalEqualityIndex op p = \case
  [VIndex x, VIndex y] -> return $ VLiteral p (LBool (equalityOp op x y))
  args -> return $ VBuiltin p (Equals EqIndex op) args

evalEqualityNat :: EqualityOp -> EvalBuiltin
evalEqualityNat op p = \case
  [VNat x, VNat y] -> return $ VLiteral p (LBool (equalityOp op x y))
  args -> return $ VBuiltin p (Equals EqNat op) args

evalEqualityInt :: EqualityOp -> EvalBuiltin
evalEqualityInt op p = \case
  [VInt x, VInt y] -> return $ VLiteral p (LBool (equalityOp op x y))
  args -> return $ VBuiltin p (Equals EqInt op) args

evalEqualityRat :: EqualityOp -> EvalBuiltin
evalEqualityRat op p = \case
  [VRat x, VRat y] -> return $ VLiteral p (LBool (equalityOp op x y))
  args -> return $ VBuiltin p (Equals EqRat op) args

evalFromNatToIndex :: Int -> EvalBuiltin
evalFromNatToIndex v p = \case
  [_, VNat n, VNat x] -> return $ VLiteral p $ LIndex n x
  args -> return $ VBuiltin p (FromNat v FromNatToIndex) args

evalFromNatToNat :: Int -> EvalBuiltin
evalFromNatToNat v p = \case
  [_, ExplicitArg _ x] -> return x
  args -> return $ VBuiltin p (FromNat v FromNatToNat) args

evalFromNatToInt :: Int -> EvalBuiltin
evalFromNatToInt v p = \case
  [_, VNat x] -> return $ VLiteral p $ LInt x
  args -> return $ VBuiltin p (FromNat v FromNatToInt) args

evalFromNatToRat :: Int -> EvalBuiltin
evalFromNatToRat v p = \case
  [_, VNat x] -> return $ VLiteral p $ LRat (fromIntegral x)
  args -> return $ VBuiltin p (FromNat v FromNatToRat) args

evalFromRatToRat :: EvalBuiltin
evalFromRatToRat p = \case
  [ExplicitArg _ x] -> return x
  args -> return $ VBuiltin p (FromRat FromRatToRat) args

evalIf :: EvalBuiltin
evalIf p = \case
  [_, VBool True, e1, _e2] -> return $ argExpr e1
  [_, VBool False, _e1, e2] -> return $ argExpr e2
  args -> return $ VBuiltin p If args

evalAt :: EvalBuiltin
evalAt p = \case
  [_, _, ExplicitArg _ (VLVec _ es _), VIndex i] -> return $ es !! fromIntegral i
  args -> return $ VBuiltin p At args

evalFoldList :: EvalBuiltin
evalFoldList p = \case
  [_, _, _f, e, ExplicitArg _ (VConstructor _ Nil [_])] -> do
    return $ argExpr e
  [toT, fromT, f, e, ExplicitArg _ (VConstructor _ Cons [_, x, xs'])] -> do
    r <- evalFoldList p [toT, fromT, f, e, xs']
    evalApp (argExpr f) [x, ExplicitArg p r]
  args -> do
    return $ VBuiltin p (Fold FoldList) args

evalFoldVector :: EvalBuiltin
evalFoldVector p = \case
  [f, e, ExplicitArg _ (VLVec _ v _)] ->
    foldrM f' (argExpr e) v
    where
      f' x r = evalApp (argExpr f) [ExplicitArg p x, ExplicitArg p r]
  args ->
    return $ VBuiltin p (Fold FoldVector) args

evalForeach :: EvalBuiltin
evalForeach p = \case
  [tRes, VNat n, ExplicitArg _ f] -> do
    let fn i = evalApp f [ExplicitArg p (VLiteral p (LIndex n i))]
    xs <- traverse fn [0 .. (n - 1 :: Int)]
    return $ mkVLVec p xs (argExpr tRes)
  args -> return $ VBuiltin p Foreach args

evalTypeClassOp ::
  MonadNorm m =>
  Provenance ->
  TypeClassOp ->
  [GenericArg NormExpr] ->
  m NormExpr
evalTypeClassOp _p _op args = do
  let (inst, remainingArgs) = findInstanceArg args
  evalApp inst remainingArgs

-----------------------------------------------------------------------------
-- Derived

-- TODO define in terms of language

evalImplies :: EvalBuiltin
evalImplies p = \case
  [e1, e2] -> do
    ne1 <- ExplicitArg p <$> evalNot p [e1]
    evalOr p [ne1, e2]
  args -> return $ VBuiltin p Implies args

evalMapList :: EvalBuiltin
evalMapList p = \case
  [_, tTo, _f, ExplicitArg _ (VConstructor _ Nil _)] ->
    return $ VConstructor p Nil [tTo]
  [tFrom, tTo, f, ExplicitArg _ (VConstructor _ Cons [x, xs])] -> do
    x' <- ExplicitArg p <$> evalApp (argExpr f) [x]
    xs' <- ExplicitArg p <$> evalMapList p [tFrom, tTo, f, xs]
    return $ VConstructor p Cons [tTo, x', xs']
  args -> return $ VBuiltin p (Map MapList) args

evalMapVec :: EvalBuiltin
evalMapVec p = \case
  [_n, _t1, t2, ExplicitArg _ f, ExplicitArg _ (VLVec _ xs _)] -> do
    xs' <- traverse (\x -> evalApp f [ExplicitArg p x]) xs
    return $ mkVLVec p xs' (argExpr t2)
  args -> return $ VBuiltin p (Map MapVector) args

evalFromVecToList :: Int -> EvalBuiltin
evalFromVecToList n p args = return $ case args of
  [tElem, ExplicitArg _ (VLVec _ xs _)] -> mkNList p (argExpr tElem) xs
  _ -> VBuiltin p (FromVec n FromVecToList) args

evalFromVecToVec :: Int -> EvalBuiltin
evalFromVecToVec n p = \case
  [ExplicitArg _ e] -> return e
  args -> return $ VBuiltin p (FromVec n FromVecToVec) args

-----------------------------------------------------------------------------
-- Meta-variable forcing

-- | Recursively forces the evaluation of any meta-variables that are blocking
-- evaluation.
forceExpr :: forall m. MonadNorm m => NormExpr -> m (Maybe NormExpr, MetaSet)
forceExpr = go
  where
    go :: NormExpr -> m (Maybe NormExpr, MetaSet)
    go = \case
      VMeta _ m spine -> goMeta m spine
      VBuiltin p b spine -> goBuiltin p b spine
      _ -> return (Nothing, mempty)

    goMeta :: MetaID -> Spine -> m (Maybe NormExpr, MetaSet)
    goMeta m spine = do
      metaSubst <- asks snd
      case MetaMap.lookup m metaSubst of
        Just solution -> do
          normMetaExpr <- evalApp (normalised solution) spine
          (maybeForcedExpr, blockingMetas) <- go normMetaExpr
          let forcedExpr = maybe (Just normMetaExpr) Just maybeForcedExpr
          return (forcedExpr, blockingMetas)
        Nothing -> return (Nothing, MetaSet.singleton m)

    goBuiltin :: Provenance -> Builtin -> Spine -> m (Maybe NormExpr, MetaSet)
    goBuiltin p b spine = case b of
      Constructor {} -> return (Nothing, mempty)
      Foreach -> return (Nothing, mempty)
      TypeClassOp {} -> return (Nothing, mempty)
      _ -> do
        (argResults, argsReduced, argBlockingMetas) <- unzip3 <$> traverse goBuiltinArg spine
        let anyArgsReduced = or argsReduced
        let blockingMetas = MetaSet.unions argBlockingMetas
        result <-
          if not anyArgsReduced
            then return Nothing
            else do
              Just <$> evalBuiltin p b argResults
        return (result, blockingMetas)

    goBuiltinArg :: NormArg -> m (NormArg, Bool, MetaSet)
    goBuiltinArg arg
      -- We assume that non-explicit args aren't depended on computationally
      -- (this may not hold in future.)
      | not (isExplicit arg) = return (arg, False, mempty)
      | otherwise = do
          (maybeResult, blockingMetas) <- go (argExpr arg)
          let result = maybe arg (`replaceArgExpr` arg) maybeResult
          let reduced = isJust maybeResult
          return (result, reduced, blockingMetas)

-----------------------------------------------------------------------------
-- Other

currentPass :: Doc ()
currentPass = "normalisation by evaluation"

showEntry :: MonadNorm m => Env -> CheckedExpr -> m ()
showEntry _env _expr = do
  -- logDebug MaxDetail $ "nbe-entry" <+> prettyVerbose expr -- <+> "   { env=" <+> prettyVerbose env <+> "}")
  incrCallDepth

showExit :: MonadNorm m => NormExpr -> m ()
showExit _result = do
  decrCallDepth

-- logDebug  MaxDetail ("nbe-exit" <+> prettyVerbose result)
