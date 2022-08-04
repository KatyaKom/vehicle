module Vehicle.Compile.Prelude.Patterns where

import Data.List.NonEmpty (NonEmpty(..))

import Vehicle.Language.AST
import Vehicle.Language.StandardLibrary.Names

--------------------------------------------------------------------------------
-- Universes
--------------------------------------------------------------------------------

pattern TypeUniverse :: Provenance -> UniverseLevel -> Expr binder var
pattern TypeUniverse p l = Universe p (TypeUniv l)

pattern LinearityUniverse :: Provenance -> Expr binder var
pattern LinearityUniverse p = Universe p LinearityUniv

pattern PolarityUniverse :: Provenance -> Expr binder var
pattern PolarityUniverse p = Universe p PolarityUniv

--------------------------------------------------------------------------------
-- Variables
--------------------------------------------------------------------------------

pattern FreeVar :: Provenance -> Identifier -> Expr binder DBVar
pattern FreeVar p ident = Var p (Free ident)

pattern BoundVar :: Provenance -> DBIndex -> Expr binder DBVar
pattern BoundVar p index = Var p (Bound index)

--------------------------------------------------------------------------------
-- Utils
--------------------------------------------------------------------------------

pattern BuiltinExpr :: Provenance
                    -> Builtin
                    -> NonEmpty (Arg binder var)
                    -> Expr binder var
pattern BuiltinExpr p b args <- App p (Builtin _ b) args
  where BuiltinExpr p b args =  App p (Builtin p b) args

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

pattern BoolType :: Provenance -> Expr binder var
pattern BoolType p = Builtin p Bool

-- | The annotated Bool type used only during type-checking
pattern AnnBoolType :: Provenance
                    -> Expr binder var
                    -> Expr binder var
                    -> Expr binder var
pattern
  AnnBoolType p lin pol <- BuiltinExpr p Bool
    [ IrrelevantImplicitArg _ lin
    , IrrelevantImplicitArg _ pol
    ]
  where
  AnnBoolType p lin pol = BuiltinExpr p Bool
    [ IrrelevantImplicitArg p lin
    , IrrelevantImplicitArg p pol
    ]

pattern NatType :: Provenance -> Expr binder var
pattern NatType p = Builtin p Nat

pattern IntType :: Provenance -> Expr binder var
pattern IntType p = Builtin p Int

pattern RatType :: Provenance -> Expr binder var
pattern RatType p = Builtin p Rat

-- | The annotated Bool type used only during type-checking
pattern AnnRatType :: Provenance -> Expr binder var -> Expr binder var
pattern AnnRatType p lin <- BuiltinExpr p Rat [ IrrelevantImplicitArg _ lin ]
  where AnnRatType p lin =  BuiltinExpr p Rat [ IrrelevantImplicitArg p lin ]

pattern ListType :: Provenance -> Expr binder var -> Expr binder var
pattern ListType p tElem <- BuiltinExpr p List [ExplicitArg _ tElem]
  where ListType p tElem =  BuiltinExpr p List [ExplicitArg p tElem]

pattern VectorType :: Provenance
                   -> Expr binder var
                   -> Expr binder var
                   -> Expr binder var
pattern
  VectorType p tElem tDim <- BuiltinExpr p Vector
    [ ExplicitArg _ tElem
    , ExplicitArg _ tDim
    ]
  where
  VectorType p tElem tDim = BuiltinExpr p Vector
    [ ExplicitArg p tElem
    , ExplicitArg p tDim
    ]

pattern TensorType :: Provenance
                   -> Expr binder var
                   -> Expr binder var
                   -> Expr binder var
pattern
  TensorType p tElem tDims <- BuiltinExpr p Tensor
    [ ExplicitArg _ tElem
    , ExplicitArg _ tDims
    ]
  where
  TensorType p tElem tDims = BuiltinExpr p Tensor
    [ ExplicitArg p tElem
    , ExplicitArg p tDims
    ]

pattern IndexType :: Provenance -> Expr binder var -> Expr binder var
pattern IndexType p tSize <- BuiltinExpr p Index [ ExplicitArg _ tSize ]
  where IndexType p tSize =  BuiltinExpr p Index [ ExplicitArg p tSize ]

pattern ConcreteIndexType :: Provenance -> Int -> Expr binder var
pattern ConcreteIndexType p n <- IndexType p (NatLiteral _ n)
  where ConcreteIndexType p n =  IndexType p (NatLiteral p n)

--------------------------------------------------------------------------------
-- Type classes
--------------------------------------------------------------------------------

pattern BuiltinTypeClass :: Provenance
                         -> TypeClass
                         -> NonEmpty (Arg binder var)
                         -> Expr binder var
pattern BuiltinTypeClass p tc args <- BuiltinExpr p (TypeClass tc) args
  where BuiltinTypeClass p tc args =  BuiltinExpr p (TypeClass tc) args

pattern HasVecLitsExpr :: Provenance
                          -> Int
                          -> Expr binder var
                          -> Expr binder var
                          -> Expr binder var
pattern
  HasVecLitsExpr p n tElem tCont <- BuiltinTypeClass p (HasVecLits n)
    [ ExplicitArg _ tElem
    , ExplicitArg _ tCont
    ]
  where
  HasVecLitsExpr p n tElem tCont = BuiltinTypeClass p (HasVecLits n)
    [ ExplicitArg p tElem
    , ExplicitArg p tCont
    ]

pattern HasFoldExpr :: Provenance
                      -> Expr binder var
                      -> Expr binder var
                      -> Expr binder var
pattern
  HasFoldExpr p tElem tCont <- BuiltinTypeClass p HasFold
    [ ExplicitArg _ tElem
    , ExplicitArg _ tCont
    ]
  where
  HasFoldExpr p tElem tCont = BuiltinTypeClass p HasFold
    [ ExplicitArg p tElem
    , ExplicitArg p tCont
    ]

pattern HasQuantifierInExpr :: Provenance
                            -> Quantifier
                            -> Expr binder var
                            -> Expr binder var
                            -> Expr binder var
pattern
  HasQuantifierInExpr ann q tElem tCont <- BuiltinTypeClass ann (HasQuantifierIn q)
    [ ExplicitArg _ tElem
    , ExplicitArg _ tCont
    ]
  where
  HasQuantifierInExpr ann q tElem tCont = BuiltinTypeClass ann (HasQuantifierIn q)
    [ ExplicitArg ann tElem
    , ExplicitArg ann tCont
    ]

pattern HasNatLitsExpr :: Provenance
                       -> Int
                       -> Expr binder var
                       -> Expr binder var
pattern
  HasNatLitsExpr ann n t <- BuiltinTypeClass ann (HasNatLits n)
    [ ExplicitArg _ t
    ]
  where
  HasNatLitsExpr ann n t = BuiltinTypeClass ann (HasNatLits n)
    [ ExplicitArg ann t
    ]

pattern HasRatLitsExpr :: Provenance
                       -> Expr binder var
                       -> Expr binder var
pattern
  HasRatLitsExpr ann t <- BuiltinTypeClass ann HasRatLits
    [ ExplicitArg _ t
    ]
  where
  HasRatLitsExpr ann t = BuiltinTypeClass ann HasRatLits
    [ ExplicitArg ann t
    ]

pattern HasArithOp2Expr :: Provenance
                       -> TypeClass
                       -> Expr binder var
                       -> Expr binder var
                       -> Expr binder var
                       -> Expr binder var
pattern
  HasArithOp2Expr ann tc t1 t2 t3 <-
    BuiltinTypeClass ann tc
      [ ExplicitArg _ t1
      , ExplicitArg _ t2
      , ExplicitArg _ t3
      ]
  where
  HasArithOp2Expr ann tc t1 t2 t3 =
    BuiltinTypeClass ann tc
      [ ExplicitArg ann t1
      , ExplicitArg ann t2
      , ExplicitArg ann t3
      ]

pattern HasAddExpr :: Provenance
                   -> Expr binder var
                   -> Expr binder var
                   -> Expr binder var
                   -> Expr binder var
pattern HasAddExpr ann t1 t2 t3 = HasArithOp2Expr ann HasAdd t1 t2 t3

pattern HasSubExpr :: Provenance
                   -> Expr binder var
                   -> Expr binder var
                   -> Expr binder var
                   -> Expr binder var
pattern HasSubExpr ann t1 t2 t3 = HasArithOp2Expr ann HasSub t1 t2 t3

pattern HasMulExpr :: Provenance
                   -> Expr binder var
                   -> Expr binder var
                   -> Expr binder var
                   -> Expr binder var
pattern HasMulExpr ann t1 t2 t3 = HasArithOp2Expr ann HasMul t1 t2 t3

pattern HasDivExpr :: Provenance
                   -> Expr binder var
                   -> Expr binder var
                   -> Expr binder var
                   -> Expr binder var
pattern HasDivExpr ann t1 t2 t3 = HasArithOp2Expr ann HasDiv t1 t2 t3

pattern HasNegExpr :: Provenance
                   -> Expr binder var
                   -> Expr binder var
                   -> Expr binder var
pattern
  HasNegExpr ann argType resType <-
    BuiltinTypeClass ann HasNeg
      [ ExplicitArg _ argType
      , ExplicitArg _ resType
      ]
  where
  HasNegExpr ann argType resType =
    BuiltinTypeClass ann HasNeg
      [ ExplicitArg ann argType
      , ExplicitArg ann resType
      ]

pattern HasOrdExpr :: Provenance
                   -> OrderOp
                  -> Expr binder var
                  -> Expr binder var
                  -> Expr binder var
                   -> Expr binder var
pattern
  HasOrdExpr p ord arg1Type arg2Type resType <-
    BuiltinTypeClass p (HasOrd ord)
      [ ExplicitArg _ arg1Type
      , ExplicitArg _ arg2Type
      , ExplicitArg _ resType
      ]
  where
  HasOrdExpr p ord arg1Type arg2Type resType =
    BuiltinTypeClass p (HasOrd ord)
      [ ExplicitArg p arg1Type
      , ExplicitArg p arg2Type
      , ExplicitArg p resType
      ]

pattern HasEqExpr :: Provenance
                  -> EqualityOp
                  -> Expr binder var
                  -> Expr binder var
                  -> Expr binder var
                  -> Expr binder var
pattern
  HasEqExpr p eq arg1Type arg2Type resType <-
    BuiltinTypeClass p (HasEq eq)
      [ ExplicitArg _ arg1Type
      , ExplicitArg _ arg2Type
      , ExplicitArg _ resType
      ]
  where
  HasEqExpr p eq arg1Type arg2Type resType =
    BuiltinTypeClass p (HasEq eq)
      [ ExplicitArg p arg1Type
      , ExplicitArg p arg2Type
      , ExplicitArg p resType
      ]

pattern HasQuantifierExpr :: Quantifier
                          -> Provenance
                          -> Expr binder var
                          -> Expr binder var
pattern
  HasQuantifierExpr q p tDomain <-
    BuiltinTypeClass p (HasQuantifier q)
      [ ExplicitArg _ tDomain
      , ExplicitArg _ _
      , ExplicitArg _ _
      ]
  where
  HasQuantifierExpr q p tDomain =
    BuiltinTypeClass p (HasQuantifier q)
      [ ExplicitArg p tDomain
      , ExplicitArg p (BoolType p)
      , ExplicitArg p (BoolType p)
      ]

--------------------------------------------------------------------------------
-- Literals
--------------------------------------------------------------------------------
{-
pattern LiteralExpr :: Provenance
                    -> Expr binder var
                    -> Expr binder var
                    -> Literal
                    -> Expr binder var
pattern
  LiteralExpr ann litType litTC lit <-
    App ann (Literal _ lit)
      [ ImplicitArg _ litType
      , InstanceArg _ (PrimDict _ litTC)
      ]
  where
  LiteralExpr ann litType litTC lit =
    App ann (Literal ann lit)
      [ ImplicitArg ann litType
      , InstanceArg ann (PrimDict ann litTC)
      ]
-}

--------------------------------------------------------------------------------
-- Literals
--------------------------------------------------------------------------------

pattern UnitLiteral :: Provenance -> Expr binder var
pattern UnitLiteral ann = Literal ann LUnit

pattern BoolLiteral :: Provenance -> Bool -> Expr binder var
pattern BoolLiteral ann n = Literal ann (LBool n)

pattern IndexLiteral :: Provenance -> Int -> Int -> Expr binder var
pattern IndexLiteral ann n x = Literal ann (LIndex n x)

pattern NatLiteral :: Provenance -> Int -> Expr binder var
pattern NatLiteral ann n = Literal ann (LNat n)

pattern IntLiteral :: Provenance -> Int -> Expr binder var
pattern IntLiteral ann n = Literal ann (LInt n)

pattern RatLiteral :: Provenance -> Rational -> Expr binder var
pattern RatLiteral ann n = Literal ann (LRat n)

pattern VecLiteral :: Provenance
                   -> Expr binder var
                   -> [Expr binder var]
                   -> Expr binder var
pattern VecLiteral p tElem xs <- App p (LVec _ xs) [ ImplicitArg _ tElem ]
  where VecLiteral p tElem xs =  App p (LVec p xs) [ ImplicitArg p tElem ]

-- | During type-checking VecLiterals may have an extra irrelevant instance argument
-- at the end. This matches on that case.
pattern AnnVecLiteral :: Provenance
                      -> Expr binder var
                      -> [Expr binder var]
                      -> Expr binder var
pattern AnnVecLiteral p tElem xs <- App p (LVec _ xs) (ImplicitArg _ tElem :| _)

pattern TrueExpr :: Provenance -> Expr binder var
pattern TrueExpr ann = BoolLiteral ann True

pattern FalseExpr :: Provenance -> Expr binder var
pattern FalseExpr ann = BoolLiteral ann False

--------------------------------------------------------------------------------
-- Expressions
--------------------------------------------------------------------------------
-- Quantifier

-- | Matches on `forall` and `exists`, but not `foreach`
pattern QuantifierTCExpr :: Provenance
                         -> Quantifier
                         -> Binder binder var
                         -> Expr binder var
                         -> Expr binder var
pattern
  QuantifierTCExpr p q binder body <-
    App p (Builtin _ (TypeClassOp (QuantifierTC q)))
      [ ImplicitArg _ _
      , ImplicitArg _ _
      , ImplicitArg _ _
      , InstanceArg _ _
      , ExplicitArg _ (Lam _ binder body)
      ]

pattern ForallTCExpr :: Provenance
                     -> Binder binder var
                     -> Expr binder var
                     -> Expr binder var
pattern ForallTCExpr p binder body <- QuantifierTCExpr p Forall binder body

pattern ExistsTCExpr :: Provenance
                     -> Binder binder var
                     -> Expr binder var
                     -> Expr binder var
pattern ExistsTCExpr p binder body <- QuantifierTCExpr p Exists binder body

pattern ExistsRatExpr :: Provenance
                      -> DBBinder
                      -> DBExpr
                      -> DBExpr
pattern
  ExistsRatExpr p binder body <-
    App p (FreeVar _ PostulateExistsRat)
      [ ExplicitArg _ (Lam _ binder body)
      ]
  where
  ExistsRatExpr p binder body =
    App p (FreeVar p PostulateExistsRat)
      [ ExplicitArg p (Lam p binder body)
      ]

pattern ForallRatExpr :: Provenance
                      -> DBBinder
                      -> DBExpr
                      -> DBExpr
pattern
  ForallRatExpr p binder body <-
    App p (FreeVar _ PostulateForallRat)
      [ ExplicitArg _ (Lam _ binder body)
      ]
  where
  ForallRatExpr p binder body =
    App p (FreeVar p PostulateForallRat)
      [ ExplicitArg p (Lam p binder body)
      ]

--------------------------------------------------------------------------------
-- QuantifierIn

pattern QuantifierInTCExpr :: Quantifier
                           -> Provenance
                           -> Expr binder var
                           -> Binder binder var
                           -> Expr binder var
                           -> Expr binder var
                           -> Expr binder var
pattern
  QuantifierInTCExpr q p tCont binder body container <-
    App p (Builtin _ (TypeClassOp (QuantifierInTC q)))
      [ ImplicitArg _ _
      , ImplicitArg _ tCont
      , ImplicitArg _ _
      , InstanceArg _ _
      , ExplicitArg _ (Lam _ binder body)
      , ExplicitArg _ container
      ]

pattern ForallInTCExpr :: Provenance
                       -> Expr binder var
                       -> Binder binder var
                       -> Expr binder var
                       -> Expr binder var
                       -> Expr binder var
pattern ForallInTCExpr ann tCont binder body container <-
  QuantifierInTCExpr Forall ann tCont binder body container

pattern ExistsInTCExpr :: Provenance
                       -> Expr binder var
                       -> Binder binder var
                       -> Expr binder var
                       -> Expr binder var
                       -> Expr binder var
pattern ExistsInTCExpr ann tCont binder body container <-
  QuantifierInTCExpr Exists ann tCont binder body container

--------------------------------------------------------------------------------
-- IfExpr

pattern IfExpr :: Provenance
               -> Expr binder var
               -> [Arg binder var]
               -> Expr binder var
pattern
  IfExpr ann tRes args <-
    App ann (Builtin _ If)
      (  ImplicitArg _ tRes
      :| args
      )
  where
  IfExpr ann tRes args =
    App ann (Builtin ann If)
      (  ImplicitArg ann tRes
      :| args
      )

--------------------------------------------------------------------------------
-- Conversion operations

pattern FromNatExpr :: Provenance
                    -> Int
                    -> FromNatDomain
                    -> NonEmpty (Arg binder var)
                    -> Expr binder var
pattern FromNatExpr p n dom args <- BuiltinExpr p (FromNat n dom) args

pattern FromRatExpr :: Provenance
                    -> FromRatDomain
                    -> NonEmpty (Arg binder var)
                    -> Expr binder var
pattern FromRatExpr p dom args <- BuiltinExpr p (FromRat dom) args

pattern FromVecExpr :: Provenance
                    -> Int
                    -> FromVecDomain
                    -> [Arg binder var]
                    -> Expr binder var
pattern FromVecExpr p n dom explicitArgs <-
  App p (Builtin _ (FromVec n dom))
    ( ImplicitArg _ _
    :| explicitArgs
    )

--------------------------------------------------------------------------------
-- Boolean operations

pattern BooleanOp2Expr :: Builtin
                       -> Provenance
                       -> NonEmpty (Arg binder var)
                       -> Expr binder var
pattern BooleanOp2Expr op p explicitArgs <- App p (Builtin _ op) explicitArgs
  where BooleanOp2Expr op p explicitArgs =  App p (Builtin p op) explicitArgs

pattern AndExpr :: Provenance -> NonEmpty (Arg binder var) -> Expr binder var
pattern AndExpr p explicitArgs <- BooleanOp2Expr And p explicitArgs
  where AndExpr p explicitArgs =  BooleanOp2Expr And p explicitArgs

pattern OrExpr :: Provenance -> NonEmpty (Arg binder var) -> Expr binder var
pattern OrExpr p explicitArgs <- BooleanOp2Expr Or p explicitArgs
  where OrExpr p explicitArgs =  BooleanOp2Expr Or p explicitArgs

pattern ImpliesExpr :: Provenance -> NonEmpty (Arg binder var) -> Expr binder var
pattern ImpliesExpr p explicitArgs <- BooleanOp2Expr Implies p explicitArgs
  where ImpliesExpr p explicitArgs =  BooleanOp2Expr Implies p explicitArgs

pattern NotExpr :: Provenance -> NonEmpty (Arg binder var) -> Expr binder var
pattern NotExpr p explicitArgs <- App p (Builtin _ Not) explicitArgs
  where NotExpr p explicitArgs =  App p (Builtin p Not) explicitArgs

--------------------------------------------------------------------------------
-- NumericOp2


pattern NegExpr :: Provenance
                -> NegDomain
                -> NonEmpty (Arg binder var)
                -> Expr binder var
pattern NegExpr p dom args = BuiltinExpr p (Neg dom) args


pattern AddExpr :: Provenance
                -> AddDomain
                -> NonEmpty (Arg binder var)
                -> Expr binder var
pattern AddExpr p dom args = BuiltinExpr p (Add dom) args

pattern SubExpr :: Provenance
                -> SubDomain
                -> NonEmpty (Arg binder var)
                -> Expr binder var
pattern SubExpr p dom args = BuiltinExpr p (Sub dom) args

pattern MulExpr :: Provenance
                -> MulDomain
                -> NonEmpty (Arg binder var)
                -> Expr binder var
pattern MulExpr p dom args = BuiltinExpr p (Mul dom) args

pattern DivExpr :: Provenance
                -> DivDomain
                -> NonEmpty (Arg binder var)
                -> Expr binder var
pattern DivExpr p dom args = BuiltinExpr p (Div dom) args

{-
--------------------------------------------------------------------------------
-- Not

pattern NegExpr :: Provenance
                -> Expr binder var
                -> Expr binder var
                -> [Arg binder var]
                -> Expr binder var
pattern
  NegExpr ann t1 t2 explicitArgs <-
    App ann (Builtin _ Neg)
      (  ImplicitArg _ t1
      :| ImplicitArg _ t2
      :  InstanceArg _ _
      :  explicitArgs
      )
  where
  NegExpr ann t1 t2 explicitArgs =
    App ann (Builtin ann Neg)
      (  ImplicitArg ann t1
      :| ImplicitArg ann t2
      :  InstanceArg ann (PrimDict ann (HasNegExpr ann t1 t2))
      :  explicitArgs
      )
-}
--------------------------------------------------------------------------------
-- EqualityOp

--pattern BuiltinEquality :: Provenance -> EqualityOp -> Expr binder var
--pattern BuiltinEquality ann eq = Builtin ann (EqualityOp eq)

pattern EqualityTCExpr :: Provenance
                -> EqualityOp
                -> Expr binder var
                -> Expr binder var
                -> Expr binder var
                -> [Arg binder var]
                -> Expr binder var
pattern
  EqualityTCExpr p op t1 t2 t3 explicitArgs <-
    App p (Builtin _ (TypeClassOp (EqualsTC op)))
      (  ImplicitArg _ t1
      :| ImplicitArg _ t2
      :  ImplicitArg _ t3
      :  InstanceArg _ _
      :  explicitArgs
      )

pattern EqualityExpr :: Provenance
                     -> EqualityDomain
                     -> EqualityOp
                     -> NonEmpty (Arg binder var)
                     -> Expr binder var
pattern
  EqualityExpr p dom op args <- App p (Builtin _ (Equals dom op)) args
  where
  EqualityExpr p dom op args =  App p (Builtin p (Equals dom op)) args

--------------------------------------------------------------------------------
-- OrderOp
{-
pattern BuiltinOrder :: Provenance -> OrderOp -> Expr binder var
pattern BuiltinOrder ann order = Builtin ann (OrderOp order)
-}
pattern OrderTCExpr :: Provenance
                    -> OrderOp
                    -> Expr binder var
                    -> Expr binder var
                    -> Expr binder var
                    -> [Arg binder var]
                    -> Expr binder var
pattern
  OrderTCExpr p op t1 t2 t3 explicitArgs <-
    App p (Builtin _ (TypeClassOp (OrderTC op)))
      (  ImplicitArg _ t1
      :| ImplicitArg _ t2
      :  ImplicitArg _ t3
      :  InstanceArg _ _
      :  explicitArgs
      )

pattern OrderExpr :: Provenance
                  -> OrderDomain
                  -> OrderOp
                  -> NonEmpty (Arg binder var)
                  -> Expr binder var
pattern
  OrderExpr p dom op args <- App p (Builtin _ (Order dom op)) args
  where
  OrderExpr p dom op args =  App p (Builtin p (Order dom op)) args

--------------------------------------------------------------------------------
-- Nil and cons

pattern NilExpr :: Provenance -> Expr binder var -> Expr binder var
pattern NilExpr p tElem <- BuiltinExpr p Nil [ImplicitArg _ tElem]
  where NilExpr p tElem =  BuiltinExpr p Nil [ImplicitArg p tElem]

pattern ConsExpr :: Provenance
                 -> Expr binder var
                 -> [Arg binder var]
                 -> Expr binder var
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


pattern AppConsExpr :: Provenance
                    -> Expr binder var
                    -> Expr binder var
                    -> Expr binder var
                    -> Expr binder var
pattern
  AppConsExpr p tElem x xs <-
    ConsExpr p tElem
      [ ExplicitArg _ x
      , ExplicitArg _ xs
      ]
  where
  AppConsExpr p tElem x xs =
    ConsExpr p tElem
      [ ExplicitArg p x
      , ExplicitArg p xs
      ]

--------------------------------------------------------------------------------
-- Foreach

pattern ForeachExpr :: Provenance
                    -> Type binder var
                    -> Expr binder var
                    -> Expr binder var
                    -> Expr binder var
pattern
  ForeachExpr p tElem size lam <-
    App p (Builtin _ Foreach)
      [ ImplicitArg _ tElem
      , ImplicitArg _ size
      , ExplicitArg _ lam
      ]
  where
  ForeachExpr p tElem size lam =
    App p (Builtin p Foreach)
      [ ImplicitArg p tElem
      , ImplicitArg p size
      , ExplicitArg p lam
      ]

--------------------------------------------------------------------------------
-- At

pattern AtExpr :: Provenance
               -> Expr binder var
               -> Expr binder var
               -> [Arg binder var]
               -> Expr binder var
pattern
  AtExpr ann tElem tDim explicitArgs <-
    App ann (Builtin _ At)
      (  ImplicitArg _ tElem
      :| ImplicitArg _ tDim
      :  explicitArgs
      )
  where
  AtExpr ann tElem tDim explicitArgs =
    App ann (Builtin ann At)
      (  ImplicitArg ann tElem
      :| ImplicitArg ann tDim
      :  explicitArgs
      )

--------------------------------------------------------------------------------
-- Sequence

pattern MapListExpr :: Provenance
                    -> Expr binder var
                    -> Expr binder var
                    -> [Arg binder var]
                    -> Expr binder var
pattern
  MapListExpr p tTo tFrom explicitArgs <-
    BuiltinExpr p (Map MapList)
      (  ImplicitArg _ tTo
      :| ImplicitArg _ tFrom
      :  explicitArgs
      )
  where
  MapListExpr p tTo tFrom explicitArgs =
    BuiltinExpr p (Map MapList)
      (  ImplicitArg p tTo
      :| ImplicitArg p tFrom
      :  explicitArgs
      )

pattern MapVectorExpr :: Provenance
                      -> Expr binder var
                      -> Expr binder var
                      -> Expr binder var
                      -> [Arg binder var]
                      -> Expr binder var
pattern
  MapVectorExpr p tTo tFrom size explicitArgs <-
    BuiltinExpr p (Map MapVector)
      (  ImplicitArg _ tTo
      :| ImplicitArg _ tFrom
      :  ImplicitArg _ size
      :  explicitArgs
      )
  where
  MapVectorExpr p tTo tFrom size explicitArgs =
    BuiltinExpr p (Map MapVector)
      (  ImplicitArg p tTo
      :| ImplicitArg p tFrom
      :  ImplicitArg p size
      :  explicitArgs
      )

--------------------------------------------------------------------------------
-- Sequence

pattern FoldVectorExpr :: Provenance
                       -> Expr binder var
                       -> Expr binder var
                       -> Expr binder var
                       -> [Arg binder var]
                       -> Expr binder var
pattern
  FoldVectorExpr p tElem size tRes explicitArgs <-
    App p (Builtin _ (Fold FoldVector))
      (  ImplicitArg _ tElem
      :| ImplicitArg _ size
      :  ImplicitArg _ tRes
      :  explicitArgs
      )
  where
  FoldVectorExpr p tElem size tRes explicitArgs =
    App p (Builtin p (Fold FoldVector))
      (  ImplicitArg p tElem
      :| ImplicitArg p size
      :  ImplicitArg p tRes
      :  explicitArgs
      )


--------------------------------------------------------------------------------
-- Auxiliary expressions
--------------------------------------------------------------------------------

pattern PolarityExpr :: Provenance -> Polarity -> Expr binder var
pattern PolarityExpr p pol = Builtin p (Polarity pol)

pattern LinearityExpr :: Provenance -> Linearity -> Expr binder var
pattern LinearityExpr p lin = Builtin p (Linearity lin)