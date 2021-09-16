{-# OPTIONS_GHC -Wno-orphans #-}

module Vehicle.Frontend.Parse
  ( parseText
  , parseFile
  , ParseError(..)
  ) where

import Control.Monad.Except (MonadError, throwError)
import Data.List.NonEmpty (NonEmpty(..))
import Data.Foldable (fold)
import GHC.Natural (naturalFromInteger)
import Data.List.NonEmpty qualified as NonEmpty (groupBy1, head, toList)
import Data.Text (Text, pack)
import Data.Text.IO qualified as T
import Prettyprinter ( (<+>), line )
import System.Exit (exitFailure)


import Vehicle.Frontend.Abs qualified as B
import Vehicle.Frontend.Layout (resolveLayout)
import Vehicle.Frontend.Lex as L (Token)
import Vehicle.Frontend.Par (pProg, myLexer)
import Vehicle.Frontend.AST qualified as V
import Vehicle.Prelude

--------------------------------------------------------------------------------
-- Parsing

parseText :: Text -> Either ParseError V.InputProg
parseText txt = case runParser True pProg txt of
  Left err1       -> Left $ BNFCParseError err1
  Right bnfcProg -> case conv bnfcProg of
    Left err2  -> Left err2
    Right prog -> Right prog

type Parser a = [L.Token] -> Either String a

runParser :: Bool -> Parser a -> Text -> Either String a
runParser topLevel p t = p (runLexer topLevel t)

runLexer :: Bool -> Text -> [L.Token]
runLexer topLevel = resolveLayout topLevel . myLexer

-- Used in both application and testing which is why it lives here.
parseFile :: FilePath -> IO V.InputProg
parseFile file = do
  contents <- T.readFile file
  case parseText contents of
    Left err -> do print (details err); exitFailure
    Right ast -> return ast

--------------------------------------------------------------------------------
-- Errors

data ParseError
  = MissingDefFunType    Symbol Provenance
  | MissingDefFunExpr    Symbol Provenance
  | DuplicateName        Symbol (NonEmpty Provenance)
  | MissingVariables     Symbol Provenance
  | BNFCParseError       String

instance MeaningfulError ParseError where
  details (MissingDefFunType name p) = UError $ UserError
    { problem    = "missing type for the declaration" <+> squotes name
    , provenance = p
    , fix        = "add a type for the declaration, e.g."
                   <> line <> line
                   <> "addOne :: Int -> Int    <-----   type declaration" <> line
                   <> "addOne x = x + 1"
    }

  details (MissingDefFunExpr name p) = UError $ UserError
    { problem    = "missing definition for the declaration" <+> squotes name
    , provenance = p
    , fix        = "add a definition for the declaration, e.g."
                   <> line <> line
                   <> "addOne :: Int -> Int" <> line
                   <> "addOne x = x + 1     <-----   declaration definition"
    }

  details (DuplicateName name p) = UError $ UserError
    { problem    = "multiple definitions found with the name" <+> squotes name
    , provenance = fold p
    , fix        = "remove or rename the duplicate definitions"
    }

  details (MissingVariables symbol p) = UError $ UserError
    { problem    = "expected at least one name after" <+> squotes symbol
    , provenance = p
    , fix        = "add one or more names after" <+> squotes symbol
    }

  -- TODO need to revamp this error, BNFC must provide some more
  -- information than a simple string surely?
  details (BNFCParseError text) = EError $ ExternalError (pack text)

--------------------------------------------------------------------------------
-- Conversion from BNFC AST
--
-- We convert from the simple AST generated automatically by BNFC to our
-- more complicated internal version of the AST which allows us to annotate
-- terms with sort-dependent types.
--
-- While doing this we:
--  1. extract the positions from the tokens generated by BNFC and convert them
--     into `Provenance` annotations.
--  2. combine function types and expressions into a single AST node

-- | Constraint for the monad stack used by the elaborator.
type MonadParse m = MonadError ParseError m

-- * Provenance

-- | A slightly shorter name for `tkProvenance`
tkProv :: IsToken a => a -> Provenance
tkProv = tkProvenance

-- * Conversion

class Convert vf vc where
  conv :: MonadParse m => vf -> m vc

instance Convert B.Arg V.InputArg where
  conv (B.ExplicitArg e) = do ce <- conv e; return $ V.Arg (V.annotation ce) Explicit ce
  conv (B.ImplicitArg e) = do
    ce <- conv e;
    let p = expandProvenance (1, 1) (V.annotation ce)
    return $ V.Arg p Implicit ce

instance Convert B.Name (WithProvenance Identifier) where
  conv n = return $ WithProvenance (tkProv n) (Identifier (tkSymbol n))

instance Convert B.LetDecl V.InputLetDecl where
  conv (B.LDecl binder e) = op2 V.LetDecl mempty (conv binder) (conv e)

instance Convert B.Binder V.InputBinder where
  conv = \case
    B.ExplicitBinderUnann name        -> convBinder mempty      name Explicit (return Nothing)
    B.ImplicitBinderUnann name        -> convBinder mempty      name Implicit (return Nothing)
    B.ExplicitBinderAnn   name tk typ -> convBinder (tkProv tk) name Explicit (Just <$> conv typ)
    B.ImplicitBinderAnn   name tk typ -> convBinder (tkProv tk) name Implicit (Just <$> conv typ)

instance Convert B.Lit V.InputExpr where
  conv = \case
    B.LitNat   v -> return $ V.LitInt  mempty (fromIntegral v)
    B.LitReal  v -> return $ V.LitRat mempty v
    B.LitTrue  p -> return $ V.LitBool (tkProv p) True
    B.LitFalse p -> return $ V.LitBool (tkProv p) False

instance Convert B.TypeClass V.InputExpr where
  conv = \case
    B.TCEq    tk e1 e2 -> op2 V.HasEq       (tkProv tk) (conv e1) (conv e2)
    B.TCOrd   tk e1 e2 -> op2 V.HasOrd      (tkProv tk) (conv e1) (conv e2)
    B.TCCont  tk e1 e2 -> op2 V.IsContainer (tkProv tk) (conv e1) (conv e2)
    B.TCTruth tk e     -> op1 V.IsTruth     (tkProv tk) (conv e)
    B.TCQuant tk e     -> op1 V.IsQuant     (tkProv tk) (conv e)
    B.TCNat   tk e     -> op1 V.IsNatural   (tkProv tk) (conv e)
    B.TCInt   tk e     -> op1 V.IsIntegral  (tkProv tk) (conv e)
    B.TCRat   tk e     -> op1 V.IsRational  (tkProv tk) (conv e)
    B.TCReal  tk e     -> op1 V.IsReal      (tkProv tk) (conv e)

instance Convert B.Expr V.InputExpr where
  conv = \case
    B.Type l                  -> return (V.Type (naturalFromInteger l))
    B.Var  n                  -> return $ V.Var  (tkProv n) (tkSymbol n)
    B.Hole n                  -> return $ V.Hole (tkProv n) (tkSymbol n)
    B.Ann e tk t              -> op2 V.Ann    (tkProv tk) (conv e) (conv t)
    B.Forall tk1 ns tk2 t     -> op2 V.Forall (tkProv tk1 <> tkProv tk2) (traverse conv =<< toNonEmpty (tkSymbol tk1) (tkProv tk1) ns) (conv t)
    B.Fun t1 tk t2            -> op2 V.Fun    (tkProv tk) (conv t1) (conv t2)
    B.Let ds e                -> op2 V.Let    mempty (traverse conv =<< toNonEmpty "let" mempty ds) (conv e)
    B.App e1 e2               -> op2 V.App    mempty (conv e1) (conv e2)
    B.Lam tk1 ns tk2 e        -> op2 V.Lam    (tkProv tk1 <> tkProv tk2) (traverse conv =<< toNonEmpty (tkSymbol tk1) (tkProv tk1) ns) (conv e)
    B.Bool tk                 -> op0 V.Bool   (tkProv tk)
    B.Prop tk                 -> op0 V.Prop   (tkProv tk)
    B.Real tk                 -> op0 V.Real   (tkProv tk)
    B.Int tk                  -> op0 V.Int    (tkProv tk)
    B.List tk t               -> op1 V.List   (tkProv tk) (conv t)
    B.Tensor tk t1 t2         -> op2 V.Tensor (tkProv tk) (conv t1) (conv t2)
    B.If tk1 e1 tk2 e2 tk3 e3 -> op3 V.If     (tkProv tk1 <> tkProv tk2 <> tkProv tk3) (conv e1) (conv e2) (conv e3)
    B.Impl e1 tk e2           -> op2 V.Impl   (tkProv tk) (conv e1) (conv e2)
    B.And e1 tk e2            -> op2 V.And    (tkProv tk) (conv e1) (conv e2)
    B.Or e1 tk e2             -> op2 V.Or     (tkProv tk) (conv e1) (conv e2)
    B.Not tk e                -> op1 V.Not    (tkProv tk) (conv e)
    B.Eq e1 tk e2             -> op2 V.Eq     (tkProv tk) (conv e1) (conv e2)
    B.Neq e1 tk e2            -> op2 V.Neq    (tkProv tk) (conv e1) (conv e2)
    B.Le e1 tk e2             -> op2 V.Le     (tkProv tk) (conv e1) (conv e2)
    B.Lt e1 tk e2             -> op2 V.Lt     (tkProv tk) (conv e1) (conv e2)
    B.Ge e1 tk e2             -> op2 V.Ge     (tkProv tk) (conv e1) (conv e2)
    B.Gt e1 tk e2             -> op2 V.Gt     (tkProv tk) (conv e1) (conv e2)
    B.Mul e1 tk e2            -> op2 V.Mul    (tkProv tk) (conv e1) (conv e2)
    B.Div e1 tk e2            -> op2 V.Div    (tkProv tk) (conv e1) (conv e2)
    B.Add e1 tk e2            -> op2 V.Add    (tkProv tk) (conv e1) (conv e2)
    B.Sub e1 tk e2            -> op2 V.Sub    (tkProv tk) (conv e1) (conv e2)
    B.Neg tk e                -> op1 V.Neg    (tkProv tk) (conv e)
    B.Cons e1 tk e2           -> op2 V.Cons   (tkProv tk) (conv e1) (conv e2)
    B.At e1 tk e2             -> op2 V.At     (tkProv tk) (conv e1) (conv e2)
    B.Every tk1 n tk2 e       -> op2 (flip V.Quant All) (tkProv tk1 <> tkProv tk2) (conv n) (conv e)
    B.Some  tk1 n tk2 e       -> op2 (flip V.Quant Any) (tkProv tk1 <> tkProv tk2) (conv n) (conv e)
    B.EveryIn tk1 n e1 tk2 e2 -> op3 (flip V.QuantIn All) (tkProv tk1 <> tkProv tk2) (conv n) (conv e1) (conv e2)
    B.SomeIn tk1 n e1 tk2 e2  -> op3 (flip V.QuantIn Any) (tkProv tk1 <> tkProv tk2) (conv n) (conv e1) (conv e2)
    B.Seq tk1 es tk2          -> op1 V.Seq     (tkProv tk1 <> tkProv tk2) (traverse conv es)
    B.Literal l               -> conv l
    B.TypeC   tc              -> conv tc

-- |Elaborate declarations.
instance Convert (NonEmpty B.Decl) V.InputDecl where
  conv = \case
    -- Elaborate a network declaration.
    (B.DeclNetw n tk t :| []) -> op2 V.DeclNetw (tkProv tk) (conv n) (conv t)

    -- Elaborate a dataset declaration.
    (B.DeclData n tk t :| []) -> op2 V.DeclData (tkProv tk) (conv n) (conv t)

    -- Elaborate a type definition.
    (B.DefType n ns t :| []) -> op3 V.DefType mempty (conv n) (traverse conv ns) (conv t)

    -- Elaborate a function definition.
    (B.DefFunType n tk t  :| [B.DefFunExpr n2 ns e]) ->
      op4 V.DefFun (tkProv tk <> tkProv n2) (conv n) (conv t) (traverse conv ns) (conv e)

    -- Why did you write the signature AFTER the function?
    (e1@B.DefFunExpr {} :| [e2@B.DefFunType {}]) ->
      conv (e2 :| [e1])

    -- Missing type or expression declaration.
    (B.DefFunType n _tk _t :| []) ->
      throwError $ MissingDefFunExpr (tkSymbol n) (tkProv n)

    (B.DefFunExpr n _ns _e :| []) ->
      throwError $ MissingDefFunType (tkSymbol n) (tkProv n)

    -- Multiple type of expression declarations with the same n.
    ds ->
      throwError $ DuplicateName symbol provs
        where
          symbol = tkSymbol $ declName $ NonEmpty.head ds
          provs  = fmap (tkProv . declName) ds

-- |Elaborate programs.
instance Convert B.Prog V.InputProg where
  conv (B.Main decls) = V.Main <$> groupDecls decls

op0 :: MonadParse m => (Provenance -> a)
    -> Provenance -> m a
op0 mk p = return $ mk p

op1 :: (MonadParse m, HasProvenance a)
    => (Provenance -> a -> b)
    -> Provenance -> m a -> m b
op1 mk p t = do
  ct <- t
  return $ mk (p <> prov ct) ct

op2 :: (MonadParse m, HasProvenance a, HasProvenance b)
    => (Provenance -> a -> b -> c)
    -> Provenance -> m a -> m b -> m c
op2 mk p t1 t2 = do
  ct1 <- t1
  ct2 <- t2
  return $ mk (p <> prov ct1 <> prov ct2) ct1 ct2

op3 :: (MonadParse m, HasProvenance a, HasProvenance b, HasProvenance c)
    => (Provenance -> a -> b -> c -> d)
    -> Provenance -> m a -> m b -> m c -> m d
op3 mk p t1 t2 t3 = do
  ct1 <- t1
  ct2 <- t2
  ct3 <- t3
  return $ mk (p <> prov ct1 <> prov ct2 <> prov ct3) ct1 ct2 ct3

op4 :: (MonadParse m, HasProvenance a, HasProvenance b, HasProvenance c, HasProvenance d)
    => (Provenance -> a -> b -> c -> d -> e)
    -> Provenance -> m a -> m b -> m c -> m d -> m e
op4 mk p t1 t2 t3 t4 = do
  ct1 <- t1
  ct2 <- t2
  ct3 <- t3
  ct4 <- t4
  return $ mk (p <> prov ct1 <> prov ct2 <> prov ct3 <> prov ct4) ct1 ct2 ct3 ct4

-- |Takes a list of declarations, and groups type and expression
--  declarations by their name.
groupDecls :: MonadParse m => [B.Decl] -> m [V.InputDecl]
groupDecls []       = return []
groupDecls (d : ds) = NonEmpty.toList <$> traverse conv (NonEmpty.groupBy1 cond (d :| ds))
  where
    cond :: B.Decl -> B.Decl -> Bool
    cond d1 d2 = isDefFun d1 && isDefFun d2 && tkSymbol (declName d1) == tkSymbol (declName d2)

-- |Check if a declaration is a network declaration.
isDefFun :: B.Decl -> Bool
isDefFun (B.DefFunType _name _args _exp) = True
isDefFun (B.DefFunExpr _ann _name _typ)  = True
isDefFun _                               = False

convBinder :: MonadParse m => Provenance -> B.Name -> Visibility -> m  (Maybe V.InputExpr) -> m V.InputBinder
convBinder p name vis mTyp = do
  typ <- mTyp
  return $ V.Binder (p <> tkProv name <> maybe mempty prov typ) vis (tkSymbol name) typ

-- |Get the name for any declaration.
declName :: B.Decl -> B.Name
declName (B.DeclNetw   n _ _) = n
declName (B.DeclData   n _ _) = n
declName (B.DefType    n _ _) = n
declName (B.DefFunType n _ _) = n
declName (B.DefFunExpr n _ _) = n

-- In theory this would be much nicer if the parser could handle this automatically
-- (see https://github.com/BNFC/bnfc/issues/371)
toNonEmpty :: MonadParse m => Symbol -> Provenance -> [a] -> m (NonEmpty a)
toNonEmpty s p []       = throwError $ MissingVariables s p
toNonEmpty _ _ (x : xs) = return $ x :| xs