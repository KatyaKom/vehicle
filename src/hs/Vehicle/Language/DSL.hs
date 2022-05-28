module Vehicle.Language.DSL
  ( DSL(..)
  , DSLExpr(..)
  , fromDSL
  , type0
  , tBool
  , tNat
  , tInt
  , tRat
  , tList
  , tTensor
  , tIndex
  , hasEq
  , hasOrd
  , hasAdd
  , hasSub
  , hasMul
  , hasDiv
  , hasNeg
  , hasConOps
  , hasNatLitsUpTo
  , hasIntLits
  , hasRatLits
  , hasConLitsOfSize
  , tMax
  , tHole
  , piType
  , nil
  , cons
  ) where

import Prelude hiding (pi)
import Data.List.NonEmpty (NonEmpty)

import Vehicle.Language.Print (prettyVerbose)
import Vehicle.Compile.Prelude

--------------------------------------------------------------------------------
-- Definition

class DSL expr where
  infixl 4 `app`
  infixr 4 ~>
  infixr 4 ~~>
  infixr 4 ~~~>

  app  :: expr -> NonEmpty (Visibility, expr) -> expr
  pi   :: Visibility -> expr -> (expr -> expr) -> expr
  lseq :: expr -> expr -> [expr] -> expr

  eApp :: expr -> NonEmpty expr -> expr
  eApp f args = app f (fmap (Explicit,) args)

  (~>) :: expr -> expr -> expr
  x ~> y = pi Explicit x (const y)

  (~~>) :: expr -> expr -> expr
  x ~~> y = pi Implicit x (const y)

  (~~~>) :: expr -> expr -> expr
  x ~~~> y = pi Instance x (const y)

  forall :: expr -> (expr -> expr) -> expr
  forall = pi Implicit

newtype DSLExpr = DSL
  { unDSL :: CheckedAnn -> BindingDepth -> CheckedExpr
  }

fromDSL :: CheckedAnn -> DSLExpr -> CheckedExpr
fromDSL ann e = unDSL e ann 0

boundVar :: BindingDepth -> DSLExpr
boundVar i = DSL $ \ann j -> Var ann (Bound (j - (i + 1)))

instance DSL DSLExpr where
  pi v argType bodyFn = DSL $ \ann i ->
    let varType = unDSL argType ann i
        var     = boundVar i
        binder  = Binder ann v Nothing varType
        body    = unDSL (bodyFn var) ann (i + 1)
    in Pi ann binder body

  app fun args = DSL $ \ann i ->
    let fun' = unDSL fun ann i
        args' = fmap (\(v, e) -> Arg ann v (unDSL e ann i)) args
    in App ann fun' args'

  lseq tElem tCont args = DSL $ \ann i ->
    SeqExpr ann
      (unDSL tElem ann i)
      (unDSL tCont ann i)
      (fmap (\e -> unDSL e ann i) args)

piType :: CheckedExpr -> CheckedExpr -> CheckedExpr
piType t1 t2 = t1 `tMax` t2

universeLevel :: CheckedExpr -> UniverseLevel
universeLevel (Type _ l) = l
universeLevel (Meta _ _) = 0 -- This is probably going to bite us, apologies.
universeLevel t          = developerError $
  "Expected argument of type Type. Found" <+> prettyVerbose t <> "."

tMax :: CheckedExpr -> CheckedExpr -> CheckedExpr
tMax t1 t2  = if universeLevel t1 > universeLevel t2 then t1 else t2

con :: Builtin -> DSLExpr
con b = DSL $ \ann _ -> Builtin ann b

--------------------------------------------------------------------------------
-- Types

type0 :: DSLExpr
type0 = DSL $ \ann _ -> Type ann 0

tBool, tNat, tInt, tRat :: DSLExpr
tBool = con Bool
tNat  = con (NumericType Nat)
tInt  = con (NumericType Int)
tRat  = con (NumericType Rat)

tTensor :: DSLExpr -> DSLExpr -> DSLExpr
tTensor tElem dims = con (ContainerType Tensor) `eApp` [tElem, dims]

tList :: DSLExpr -> DSLExpr
tList tElem = con (ContainerType List) `eApp` [tElem]

tIndex :: DSLExpr -> DSLExpr
tIndex n = con Index `eApp` [n]

tHole :: Symbol -> DSLExpr
tHole name = DSL $ \ann _ -> Hole ann name

--------------------------------------------------------------------------------
-- TypeClass

typeClass :: Builtin -> DSLExpr
typeClass op = DSL $ \ann _ -> Builtin ann op

hasSimpleTC :: TypeClass -> DSLExpr -> DSLExpr
hasSimpleTC tc tArg = typeClass (TypeClass tc) `eApp` [tArg]

hasEq :: DSLExpr -> DSLExpr
hasEq = hasSimpleTC HasEq

hasOrd :: DSLExpr -> DSLExpr
hasOrd = hasSimpleTC HasOrd

hasAdd :: DSLExpr -> DSLExpr
hasAdd = hasSimpleTC HasAdd

hasSub :: DSLExpr -> DSLExpr
hasSub = hasSimpleTC HasSub

hasMul :: DSLExpr -> DSLExpr
hasMul = hasSimpleTC HasMul

hasDiv :: DSLExpr -> DSLExpr
hasDiv = hasSimpleTC HasDiv

hasNeg :: DSLExpr -> DSLExpr
hasNeg = hasSimpleTC HasNeg

hasConOps :: DSLExpr -> DSLExpr -> DSLExpr
hasConOps tCont tElem = typeClass (TypeClass HasConOps) `eApp` [tCont, tElem]

hasNatLitsUpTo :: Int -> DSLExpr -> DSLExpr
hasNatLitsUpTo n t = typeClass (TypeClass (HasNatLitsUpTo n)) `eApp` [t]

hasIntLits :: DSLExpr -> DSLExpr
hasIntLits t = typeClass (TypeClass HasIntLits) `eApp` [t]

hasRatLits :: DSLExpr -> DSLExpr
hasRatLits t = typeClass (TypeClass HasRatLits) `eApp` [t]

hasConLitsOfSize :: Int -> DSLExpr -> DSLExpr -> DSLExpr
hasConLitsOfSize n tCont tElem =
  typeClass (TypeClass (HasConLitsOfSize n)) `eApp` [tCont, tElem]

--------------------------------------------------------------------------------
-- Operations

nil :: DSLExpr -> DSLExpr -> DSLExpr
nil tElem tCont = lseq tElem tCont []

cons :: DSLExpr -> DSLExpr -> DSLExpr -> DSLExpr
cons tElem x xs = app (con Cons) [(Implicit, tElem), (Explicit, x), (Explicit, xs)]
