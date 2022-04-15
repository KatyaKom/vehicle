{-# OPTIONS_GHC -Wno-deferred-out-of-scope-variables #-}

module Vehicle.Compile.Error where

import Control.Exception (IOException)
import Control.Monad.Except ( MonadError )
import Data.List.NonEmpty (NonEmpty)
import Prettyprinter (list)

import Vehicle.Compile.Prelude
import Vehicle.Compile.Type.Constraint
import Vehicle.Backend.Prelude (Backend)
import Vehicle.Resource.NeuralNetwork

--------------------------------------------------------------------------------
-- Compilation monad

type MonadCompile m =
  ( MonadLogger m
  , MonadError CompileError m
  )

--------------------------------------------------------------------------------
-- Compilation errors

data CompileError
  -- Parse errors
  = BNFCParseError String

  -- Errors thrown when elaborating from the BNFC internal language
  | UnknownBuiltin     Token
  | MalformedPiBinder  Token
  | MalformedLamBinder InputExpr

  -- Errors thrown when elaborating from the BNFC external language
  | MissingDefFunExpr    Provenance Symbol
  | DuplicateName        (NonEmpty Provenance) Symbol
  | MissingVariables     Provenance Symbol
  | UnchainableOrders    Provenance Order Order

  -- Errors thrown by scope checking.
  | UnboundName Symbol Provenance

  -- Errors thrown while type checking
  | UnresolvedHole
    Provenance              -- The location of the hole
    Symbol                  -- The name of the hole
  | TypeMismatch
    Provenance              -- The location of the mismatch.
    BoundCtx                -- The context at the time of the failure
    CheckedExpr             -- The possible inferred types.
    CheckedExpr             -- The expected type.
  | FailedConstraints
    (NonEmpty Constraint)
  | UnsolvedConstraints
    (NonEmpty Constraint)
  | MissingExplicitArg
    BoundCtx                -- The context at the time of the failure
    UncheckedArg            -- The non-explicit argument
    CheckedExpr             -- Expected type of the argument

  -- Resource typing errors
  | ResourceNotProvided       Identifier Provenance ResourceType
  | ResourceIOError           Identifier Provenance ResourceType IOException
  | UnsupportedResourceFormat Identifier Provenance ResourceType String
  | UnableToParseResource     Identifier Provenance ResourceType String

  | NetworkTypeIsNotAFunction              Identifier CheckedExpr
  | NetworkTypeHasNonExplicitArguments     Identifier CheckedExpr CheckedBinder
  | NetworkTypeHasHeterogeneousInputTypes  Identifier CheckedExpr CheckedExpr CheckedExpr
  | NetworkTypeHasMultidimensionalTensor   Identifier CheckedExpr InputOrOutput
  | NetworkTypeHasVariableSizeTensor       Identifier CheckedExpr InputOrOutput
  | NetworkTypeHasUnsupportedElementType   Identifier CheckedExpr InputOrOutput

  | DatasetInvalidContainerType Identifier Provenance CheckedExpr
  | DatasetInvalidElementType   Identifier Provenance CheckedExpr
  | DatasetVariableSizeTensor   Identifier Provenance CheckedExpr
  | DatasetDimensionMismatch    Identifier Provenance [Int] [Int]
  | DatasetTypeMismatch         Identifier Provenance CheckedExpr NumericType
  | DatasetInvalidNat           Identifier Provenance Int
  | DatasetInvalidFin           Identifier Provenance Int Int

  -- Backend errors
  | NoPropertiesFound
  | UnsupportedResource            Backend Provenance Identifier ResourceType
  | UnsupportedQuantifierSequence  Backend Provenance Identifier Quantifier
  | UnsupportedQuantifierPosition  Backend Provenance Identifier Quantifier Symbol
  | UnsupportedVariableType        Backend Provenance Identifier Symbol OutputExpr [Builtin]
  | UnsupportedEquality            Backend Provenance Quantifier Equality
  | UnsupportedOrder               Backend Provenance Quantifier Order
  | UnsupportedPolymorphicEquality Backend Provenance Symbol
  | UnsupportedBuiltin             Backend Provenance Builtin
  | UnsupportedNonMagicVariable    Backend Provenance Symbol
  | NonLinearConstraint            Backend Provenance Identifier OutputExpr OutputExpr
  | NoNetworkUsedInProperty        Backend Provenance Identifier
  deriving (Show)

--------------------------------------------------------------------------------
-- Some useful developer errors

unexpectedExprError :: Doc a -> Doc a -> Doc a
unexpectedExprError pass name =
  "encountered unexpected expression" <+> squotes name <+>
  "during" <+> pass <> "."

normalisationError :: Doc a -> Doc a -> b
normalisationError pass name = developerError $
  unexpectedExprError pass name <+> "We should have normalised this out."

typeError :: Doc a -> Doc a -> b
typeError pass name = developerError $
  unexpectedExprError pass name <+> "We should not be compiling types."

visibilityError :: Doc a -> Doc a -> b
visibilityError pass name = developerError $
  unexpectedExprError pass name <+> "Should not be present as explicit arguments"

resolutionError :: Doc a -> Doc a -> b
resolutionError pass name = developerError $
  unexpectedExprError pass name <+> "We should have resolved this during type-checking."

caseError :: Doc a -> Doc a -> [Doc a] -> b
caseError pass name cases = developerError $
  unexpectedExprError pass name <+> "This should already have been caught by the" <+>
  "following cases:" <+> list cases