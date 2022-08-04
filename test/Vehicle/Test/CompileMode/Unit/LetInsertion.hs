module Vehicle.Test.CompileMode.Unit.LetInsertion where

import Test.Tasty
import Test.Tasty.HUnit

import Control.Exception
import Control.Monad.Except (MonadError(..), ExceptT, runExceptT)
import Data.Text
import Data.Hashable

import Vehicle.Language.Print
import Vehicle.Compile (typeCheckExpr, typeCheck)
import Vehicle.Compile.Prelude
import Vehicle.Compile.AlphaEquivalence
import Vehicle.Compile.Error
import Vehicle.Compile.LetInsertion
import Vehicle.Compile.CoDeBruijnify

import Vehicle.Test.Utils

--------------------------------------------------------------------------------
-- Let lifting tests

letInsertionTests :: MonadTest m => m TestTree
letInsertionTests = testGroup "LetInsertion" <$>
  traverse letInsertionTest
  [ InsertionTestSpec "insertFun"
      standardFilter
      "(Nat -> Nat) -> (Nat -> Nat)"
      "let y = (Nat -> Nat) in y -> y"

  , InsertionTestSpec "insertNeg"
      standardFilter
      "\\(x : Int) -> (- x) + (- x)"
      "\\(x : Int) -> (let y = (- x) in (y + y))"

  -- Disabled due to bugs in type-checker
{-
  , testCase "insertLam" $ letInsertionTest
      standardFilter
      "(\\(x : Nat) -> x) ((\\(y : Nat) -> y) 1)"
      "let id = (\\(z : Nat) -> z) in id (id 1)"

  , testCase "insertAdd" $ letInsertionTest
      standardFilter
      "\\(x : Int) (y : Int) -> (((- x) + (- y)) / ((- x) + (- y))) + (- y)"
      "\\(x : Int) -> (let b = (- x) in (\\(y : Int) -> (let a = (- y) in (let c = (a + b) in (c / c))) + y))"
-}

  , InsertionTestSpec "insertLiftApp"
      appFilter
      "- - (1 : Int)"
      "let a = (- (1 : Int)) in (let b = (- a) in b)"
  ]

data InsertionTestSpec = InsertionTestSpec String SubexprFilter Text Text

type SubexprFilter = CheckedCoDBExpr -> Int -> Bool

standardFilter :: SubexprFilter
standardFilter e q = q > 1

appFilter :: SubexprFilter
appFilter (App{}, _)         _ = True
appFilter _                  _ = False

letInsertionTest :: MonadTest m => InsertionTestSpec -> m TestTree
letInsertionTest (InsertionTestSpec testName filter input expected) =
  unitTestCase testName $ do
    inputExpr    <- normTypeClasses =<< typeCheckExpr input
    expectedExpr <- normTypeClasses =<< typeCheckExpr expected
    result       <- insertLets filter True inputExpr

    -- Need to re-typecheck the result as let-insertion puts a Hole on
    -- each binder type.
    typedResult <- typeCheck result

    let errorMessage = layoutAsString $
          "Expected the result of let lifting" <> line <>
            indent 2 (squotes (pretty input)) <> line <>
          "to be alpha equivalent to" <> line <>
            indent 2 (squotes (prettyFriendly expectedExpr)) <> line <>
          "however the result was" <> line <>
            indent 2 (squotes (prettyFriendly typedResult))

    return $ assertBool errorMessage $
      alphaEq expectedExpr typedResult