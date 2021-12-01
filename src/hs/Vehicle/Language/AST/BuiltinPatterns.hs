module Vehicle.Language.AST.BuiltinPatterns where

import Data.List.NonEmpty (NonEmpty(..))
import Vehicle.Language.AST.Builtin
import Vehicle.Language.AST.Core

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------
-- List

pattern ListType :: ann
                 -> Expr binder var ann
                 -> Expr binder var ann
pattern
  ListType ann tElem <- App ann (BuiltinContainerType _   List) [ExplicitArg _ tElem]
  where
  ListType ann tElem =  App ann (BuiltinContainerType ann List) [ExplicitArg ann tElem]

--------------------------------------------------------------------------------
-- Tensor

pattern TensorType :: ann
                   -> Expr binder var ann
                   -> Expr binder var ann
                   -> Expr binder var ann
pattern
  TensorType ann tElem tDims <-
    App ann (BuiltinContainerType _   Tensor)
      [ ExplicitArg _ tElem
      , ExplicitArg _ tDims ]
  where
  TensorType ann tElem tDims =
    App ann (BuiltinContainerType ann Tensor)
      [ ExplicitArg ann tElem
      , ExplicitArg ann tDims ]

mkTensor :: ann
         -> Expr binder var ann
         -> [Int]
         -> Expr binder var ann
mkTensor ann tElem dims =
  let listType = ListType ann (Builtin ann (NumericType Nat)) in
  let dimExprs = fmap (Literal ann . LNat) dims in
  let dimList  = SeqExpr ann (Builtin ann (NumericType Nat)) listType dimExprs in
  App ann (BuiltinContainerType ann Tensor) (fmap (ExplicitArg ann) [tElem, dimList])

--------------------------------------------------------------------------------
-- Numeric

pattern BuiltinNumericType :: ann -> NumericType -> Expr binder var ann
pattern BuiltinNumericType ann op = Builtin ann (NumericType op)

--------------------------------------------------------------------------------
-- Boolean

pattern BuiltinBooleanType :: ann -> BooleanType -> Expr binder var ann
pattern BuiltinBooleanType ann op = Builtin ann (BooleanType op)

--------------------------------------------------------------------------------
-- Container

pattern BuiltinContainerType :: ann -> ContainerType -> Expr binder var ann
pattern BuiltinContainerType ann op = Builtin ann (ContainerType op)

--------------------------------------------------------------------------------
-- Type classes
--------------------------------------------------------------------------------

pattern BuiltinTypeClass :: ann -> TypeClass -> Expr binder var ann
pattern BuiltinTypeClass ann tc = Builtin ann (TypeClass tc)

--------------------------------------------------------------------------------
-- IsTruth

mkIsTruth :: ann
          -> BooleanType
          -> Expr binder var ann
mkIsTruth ann t = App ann (BuiltinTypeClass ann IsTruth)
  (fmap (ExplicitArg ann) [BuiltinBooleanType ann t])

--------------------------------------------------------------------------------
-- IsContainer

mkIsContainer :: ann
              -> Expr binder var ann
              -> Expr binder var ann
              -> Expr binder var ann
mkIsContainer ann tElem tCont = App ann (BuiltinTypeClass ann IsContainer)
  (fmap (ExplicitArg ann) [tElem, tCont])

--------------------------------------------------------------------------------
-- IsIntegral

pattern IsIntegralExpr :: ann
                       -> NumericType
                       -> Expr binder var ann
pattern
  IsIntegralExpr ann t <-
    App ann (BuiltinTypeClass _ IsIntegral)
      [ ExplicitArg _ (BuiltinNumericType _ t)
      ]
  where
  IsIntegralExpr ann t =
    App ann (BuiltinTypeClass ann IsIntegral)
      [ ExplicitArg ann (BuiltinNumericType ann t)
      ]

--------------------------------------------------------------------------------
-- HasOrder

pattern HasOrdExpr :: ann
                   -> Expr binder var ann
                   -> Expr binder var ann
                   -> Expr binder var ann
pattern
  HasOrdExpr ann tElem tRes <-
    App ann (BuiltinTypeClass _ HasOrd)
      [ ExplicitArg _ tElem
      , ExplicitArg _ tRes
      ]
  where
  HasOrdExpr ann tElem tRes =
    App ann (BuiltinTypeClass ann HasOrd)
      [ ExplicitArg ann tElem
      , ExplicitArg ann tRes
      ]

--------------------------------------------------------------------------------
-- HasEq

pattern HasEqExpr :: ann
                  -> Expr binder var ann
                  -> Expr binder var ann
                  -> Expr binder var ann
pattern
  HasEqExpr ann tElem tRes <-
    App ann (BuiltinTypeClass _ HasEq)
      [ ExplicitArg _ tElem
      , ExplicitArg _ tRes
      ]
  where
  HasEqExpr ann tElem tRes =
    App ann (BuiltinTypeClass ann HasEq)
      [ ExplicitArg ann tElem
      , ExplicitArg ann tRes
      ]

--------------------------------------------------------------------------------
-- Literals
--------------------------------------------------------------------------------

pattern LiteralExpr :: ann
                    -> Expr binder var ann
                    -> Literal
                    -> Expr binder var ann
pattern
  LiteralExpr ann litType lit <-
    App ann (Literal _ lit)
      [ ImplicitArg _ litType
      , InstanceArg _ _
      ]
  where
  LiteralExpr ann litType lit =
    App ann (Literal ann lit)
      [ ImplicitArg ann litType
      , InstanceArg ann (PrimDict ann litType)
      ]

--------------------------------------------------------------------------------
-- Bool

pattern LitBool :: ann -> Bool -> Expr binder var ann
pattern LitBool ann n = Literal ann (LBool n)

pattern BoolLiteralExpr :: ann
                        -> BooleanType
                        -> Bool
                        -> Expr binder var ann
pattern
  BoolLiteralExpr ann boolType bool <-
    LiteralExpr ann (BuiltinBooleanType _ boolType) (LBool bool)
  where
  BoolLiteralExpr ann boolType bool =
    LiteralExpr ann (BuiltinBooleanType ann boolType) (LBool bool)

--------------------------------------------------------------------------------
-- Nat

pattern LitNat :: ann -> Int -> Expr binder var ann
pattern LitNat ann n = Literal ann (LNat n)

pattern NatLiteralExpr :: ann
                       -> NumericType
                       -> Int
                       -> Expr binder var ann
pattern
  NatLiteralExpr ann t n <-
    LiteralExpr ann (BuiltinNumericType _ t) (LNat n)
  where
  NatLiteralExpr ann t n =
    LiteralExpr ann (BuiltinNumericType ann t) (LNat n)

--------------------------------------------------------------------------------
-- Int

pattern LitInt :: ann -> Int -> Expr binder var ann
pattern LitInt ann n = Literal ann (LInt n)

pattern IntLiteralExpr :: ann
                       -> NumericType
                       -> Int
                       -> Expr binder var ann
pattern
  IntLiteralExpr ann t n <-
    LiteralExpr ann (BuiltinNumericType _ t) (LInt n)
  where
  IntLiteralExpr ann t n =
    LiteralExpr ann (BuiltinNumericType ann t) (LInt n)

--------------------------------------------------------------------------------
-- Rat

pattern LitRat :: ann -> Rational -> Expr binder var ann
pattern LitRat ann n = Literal ann (LRat n)

pattern RatLiteralExpr :: ann
                       -> NumericType
                       -> Rational
                       -> Expr binder var ann
pattern
  RatLiteralExpr ann t n <-
    LiteralExpr ann (BuiltinNumericType _ t) (LRat n)
  where
  RatLiteralExpr ann t n =
    LiteralExpr ann (BuiltinNumericType ann t) (LRat n)

--------------------------------------------------------------------------------
-- Expressions
--------------------------------------------------------------------------------
-- Quantifier

pattern BuiltinQuantifier :: ann -> Quantifier -> Expr binder var ann
pattern BuiltinQuantifier ann q = Builtin ann (Quant q)

pattern QuantifierExpr :: Quantifier
                       -> ann
                       -> Binder binder var ann
                       -> Expr   binder var ann
                       -> Expr   binder var ann
pattern
  QuantifierExpr q ann binder body <-
    App ann (BuiltinQuantifier _ q)
      [ ImplicitArg _ _
      , ExplicitArg _ (Lam _ binder body)
      ]
  where
  QuantifierExpr q ann binder body =
    App ann (BuiltinQuantifier ann q)
      [ ImplicitArg ann (typeOf binder)
      , ExplicitArg ann (Lam ann binder body)
      ]

mkQuantifierSeq :: Quantifier
                -> ann
                -> [binder]
                -> Expr binder var ann
                -> Expr binder var ann
                -> Expr binder var ann
mkQuantifierSeq q ann names t body =
  foldl (\e name -> QuantifierExpr q ann (ExplicitBinder ann name t) e) body names

--------------------------------------------------------------------------------
-- Expressions
--------------------------------------------------------------------------------
-- Quantifier

pattern BuiltinQuantifierIn :: ann -> Quantifier -> Expr binder var ann
pattern BuiltinQuantifierIn ann q = Builtin ann (QuantIn q)

pattern QuantifierInExpr :: Quantifier
                         -> ann
                         -> Expr   binder var ann
                         -> BooleanType
                         -> Binder binder var ann
                         -> Expr   binder var ann
                         -> Expr   binder var ann
                         -> Expr   binder var ann
pattern
  QuantifierInExpr q ann tCont tRes binder body container <-
    App ann (BuiltinQuantifierIn _ q)
      [ ImplicitArg _ _
      , ImplicitArg _ tCont
      , ImplicitArg _ (BuiltinBooleanType _ tRes)
      , InstanceArg _ _
      , ExplicitArg _ (Lam _ binder body)
      , ExplicitArg _ container
      ]
  where
  QuantifierInExpr q ann tCont tRes binder body container =
    App ann (BuiltinQuantifierIn ann q)
      [ ImplicitArg ann (typeOf binder)
      , ImplicitArg ann tCont
      , ImplicitArg ann (BuiltinBooleanType ann tRes)
      , InstanceArg ann (mkIsContainer ann (typeOf binder) tCont)
      , ExplicitArg ann (Lam ann binder body)
      , ExplicitArg ann container
      ]

--------------------------------------------------------------------------------
-- IfExpr

pattern IfExpr :: ann
               -> Expr binder var ann
               -> Expr binder var ann
               -> Expr binder var ann
               -> Expr binder var ann
               -> Expr binder var ann
pattern
  IfExpr ann tRes cond e1 e2 <-
    App ann (Builtin _ If)
      [ ImplicitArg _ tRes
      , ExplicitArg _ cond
      , ExplicitArg _ e1
      , ExplicitArg _ e2
      ]
  where
  IfExpr ann tRes cond e1 e2 =
    App ann (Builtin ann If)
      [ ImplicitArg ann tRes
      , ExplicitArg ann cond
      , ExplicitArg ann e1
      , ExplicitArg ann e2
      ]

--------------------------------------------------------------------------------
-- BooleanOp2

pattern BooleanOp2Expr :: BooleanOp2
                       -> ann
                       -> BooleanType
                       -> [Arg  binder var ann]
                       -> Expr  binder var ann
pattern
  BooleanOp2Expr op ann t explicitArgs <-
    App ann (Builtin _ (BooleanOp2 op))
      (  ImplicitArg _ (BuiltinBooleanType _ t)
      :| InstanceArg _ _
      :  explicitArgs
      )
  where
  BooleanOp2Expr op ann t explicitArgs =
    App ann (Builtin ann (BooleanOp2 op))
      (  ImplicitArg ann (BuiltinBooleanType ann t)
      :| InstanceArg ann (PrimDict ann (mkIsTruth ann t))
      :  explicitArgs
      )

booleanBigOp :: forall binder var ann .
                BooleanOp2
             -> ann
             -> BooleanType
             -> Expr binder var ann
             -> Expr binder var ann
             -> Expr binder var ann
booleanBigOp op ann t containerType container =
  FoldExpr ann boolType containerType boolType $ map (ExplicitArg ann)
    [ BooleanOp2Expr op ann t []
    , BoolLiteralExpr ann t unit
    , container
    ]
  where
    unit :: Bool
    unit = case op of
      And  -> True
      Or   -> False
      Impl -> True

    boolType :: Expr binder var ann
    boolType = BuiltinBooleanType ann t

--------------------------------------------------------------------------------
-- Not

pattern NotExpr :: ann
                -> BooleanType
                -> [Arg  binder var ann]
                -> Expr  binder var ann
pattern
  NotExpr ann t explicitArgs <-
    App ann (Builtin _ Not)
      (  ImplicitArg _ (BuiltinBooleanType _ t)
      :| InstanceArg _ _
      :  explicitArgs
      )
  where
  NotExpr ann t explicitArgs =
    App ann (Builtin ann Not)
      (  ImplicitArg ann (BuiltinBooleanType ann t)
      :| InstanceArg ann (PrimDict ann (mkIsTruth ann t))
      :  explicitArgs
      )

--------------------------------------------------------------------------------
-- NumericOp2

pattern NumericOp2Expr :: NumericOp2
                       -> ann
                       -> NumericType
                       -> Expr  binder var ann
                       -> [Arg  binder var ann]
                       -> Expr  binder var ann
pattern
  NumericOp2Expr op ann t tc explicitArgs <-
    App ann (Builtin _ (NumericOp2 op))
      (  ImplicitArg _ (BuiltinNumericType _ t)
      :| InstanceArg _ tc
      :  explicitArgs
      )
  where
  NumericOp2Expr op ann t tc explicitArgs =
    App ann (Builtin ann (NumericOp2 op))
      (  ImplicitArg ann (BuiltinNumericType ann t)
      :| InstanceArg ann tc
      :  explicitArgs
      )

--------------------------------------------------------------------------------
-- Not

pattern NegExpr :: ann
                -> NumericType
                -> [Arg  binder var ann]
                -> Expr  binder var ann
pattern
  NegExpr ann t explicitArgs <-
    App ann (Builtin _ Neg)
      (  ImplicitArg _ (BuiltinNumericType _ t)
      :| InstanceArg _ _
      :  explicitArgs
      )
  where
  NegExpr ann t explicitArgs =
    App ann (Builtin ann Neg)
      (  ImplicitArg ann (BuiltinNumericType ann t)
      :| InstanceArg ann (PrimDict ann (IsIntegralExpr ann t))
      :  explicitArgs
      )

--------------------------------------------------------------------------------
-- Equality

pattern BuiltinEquality :: ann -> Equality -> Expr binder var ann
pattern BuiltinEquality ann eq = Builtin ann (Equality eq)

pattern EqualityExpr :: Equality
                     -> ann
                     -> Expr  binder var ann
                     -> BooleanType
                     -> [Arg  binder var ann]
                     -> Expr  binder var ann
pattern
  EqualityExpr eq ann tElem tRes explicitArgs <-
    App ann (BuiltinEquality _ eq)
      (  ImplicitArg _ tElem
      :| ImplicitArg _ (BuiltinBooleanType _ tRes)
      :  InstanceArg _ _
      :  explicitArgs
      )
  where
  EqualityExpr eq ann tElem tRes explicitArgs =
    App ann (BuiltinEquality ann eq)
      (  ImplicitArg ann tElem
      :| ImplicitArg ann (BuiltinBooleanType ann tRes)
      :  InstanceArg ann (PrimDict ann (HasEqExpr ann tElem (BuiltinBooleanType ann tRes)))
      :  explicitArgs
      )

--------------------------------------------------------------------------------
-- Order

pattern BuiltinOrder :: ann -> Order -> Expr binder var ann
pattern BuiltinOrder ann order = Builtin ann (Order order)

pattern OrderExpr :: Order
                  -> ann
                  -> Expr  binder var ann
                  -> BooleanType
                  -> [Arg  binder var ann]
                  -> Expr  binder var ann
pattern
  OrderExpr order ann tElem tRes explicitArgs <-
    App ann (BuiltinOrder _ order)
      (  ImplicitArg _ tElem
      :| ImplicitArg _ (BuiltinBooleanType _ tRes)
      :  InstanceArg _ _
      :  explicitArgs
      )
  where
  OrderExpr order ann tElem tRes explicitArgs =
    App ann (BuiltinOrder ann order)
      (  ImplicitArg ann tElem
      :| ImplicitArg ann (BuiltinBooleanType ann tRes)
      :  InstanceArg ann (PrimDict ann (HasOrdExpr ann tElem (BuiltinBooleanType ann tRes)))
      :  explicitArgs
      )

--------------------------------------------------------------------------------
-- Sequence

pattern SeqExpr :: ann
                -> Expr  binder var ann
                -> Expr  binder var ann
                -> [Expr binder var ann]
                -> Expr  binder var ann
pattern
  SeqExpr ann tElem tCont xs <-
    App ann (Seq _ xs)
      (  ImplicitArg _ tElem
      :| ImplicitArg _ tCont
      :  [InstanceArg _ _]
      )
  where
  SeqExpr ann tElem tCont xs =
    App ann (Seq ann xs)
      (  ImplicitArg ann tElem
      :| ImplicitArg ann tCont
      :  [InstanceArg ann (PrimDict ann (mkIsContainer ann tElem tCont))]
      )

--------------------------------------------------------------------------------
-- Cons

pattern ConsExpr :: ann
                 -> Expr  binder var ann
                 -> [Arg  binder var ann]
                 -> Expr  binder var ann
pattern
  ConsExpr ann tElem explicitArgs <-
    App ann (Builtin _ Cons)
      (  ImplicitArg _ tElem
      :| explicitArgs
      )
  where
  ConsExpr ann tElem explicitArgs =
    App ann (Builtin ann Cons)
      (  ImplicitArg ann tElem
      :| explicitArgs
      )

--------------------------------------------------------------------------------
-- At

pattern AtExpr :: ann
                -> Expr  binder var ann
                -> Expr  binder var ann
                -> [Arg binder var ann]
                -> Expr  binder var ann
pattern
  AtExpr ann tElem tDims explicitArgs <-
    App ann (Builtin _ At)
      (  ImplicitArg _ tElem
      :| ImplicitArg _ tDims
      :  explicitArgs
      )
  where
  AtExpr ann tElem tDims explicitArgs =
    App ann (Builtin ann At)
      (  ImplicitArg ann tElem
      :| ImplicitArg ann tDims
      :  explicitArgs
      )

--------------------------------------------------------------------------------
-- Sequence

pattern MapExpr :: ann
                -> Expr  binder var ann
                -> Expr  binder var ann
                -> [Arg  binder var ann]
                -> Expr  binder var ann
pattern
  MapExpr ann tTo tFrom explicitArgs <-
    App ann (Builtin _ Map)
      (  ImplicitArg _ tTo
      :| ImplicitArg _ tFrom
      :  explicitArgs
      )
  where
  MapExpr ann tTo tFrom explicitArgs =
    App ann (Builtin ann Map)
      (  ImplicitArg ann tTo
      :| ImplicitArg ann tFrom
      :  explicitArgs
      )

--------------------------------------------------------------------------------
-- Sequence

pattern FoldExpr :: ann
                 -> Expr  binder var ann
                 -> Expr  binder var ann
                 -> Expr  binder var ann
                 -> [Arg  binder var ann]
                 -> Expr  binder var ann
pattern
  FoldExpr ann tElem tCont tRes explicitArgs <-
    App ann (Builtin _ Fold)
      (  ImplicitArg _ tElem
      :| ImplicitArg _ tCont
      :  ImplicitArg _ tRes
      :  InstanceArg _ _
      :  explicitArgs
      )
  where
  FoldExpr ann tElem tCont tRes explicitArgs =
    App ann (Builtin ann Fold)
      (  ImplicitArg ann tElem
      :| ImplicitArg ann tCont
      :  ImplicitArg ann tRes
      :  InstanceArg ann (PrimDict ann (mkIsContainer ann tElem tCont))
      :  explicitArgs
      )