module Vehicle.Test.Unit.Compile.LetInsertion where

import Data.Text (Text)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool)
import Vehicle.Compile (loadLibrary, parseAndTypeCheckExpr, typeCheckExpr)
import Vehicle.Compile.LetInsertion (insertLets)
import Vehicle.Compile.Prelude
  ( Contextualised (..),
    Expr (App),
    Pretty (pretty),
    emptyDBCtx,
    indent,
    layoutAsString,
    line,
    squotes,
  )
import Vehicle.Compile.Print (prettyFriendly)
import Vehicle.Expr.AlphaEquivalence (AlphaEquivalence (alphaEq))
import Vehicle.Expr.CoDeBruijn (CoDBExpr)
import Vehicle.Libraries.StandardLibrary (standardLibrary)
import Vehicle.Test.Unit.Common (normTypeClasses, unitTestCase)

--------------------------------------------------------------------------------
-- Let lifting tests

letInsertionTests :: TestTree
letInsertionTests =
  testGroup "LetInsertion" . fmap letInsertionTest $
    [ InsertionTestSpec
        "insertFun"
        standardFilter
        "(Nat -> Nat) -> (Nat -> Nat)"
        "let y = (Nat -> Nat) in y -> y",
      InsertionTestSpec
        "insertNeg"
        standardFilter
        "\\(x : Int) -> (- x) + (- x)"
        "\\(x : Int) -> (let y = (- x) in (y + y))"
        -- Disabled due to bugs in type-checker
        -- , testCase "insertLam" $ letInsertionTest
        --     standardFilter
        --     "(\\(x : Nat) -> x) ((\\(y : Nat) -> y) 1)"
        --     "let id = (\\(z : Nat) -> z) in id (id 1)"

        -- Disabled due to bugs in type-checker
        -- , testCase "insertAdd" $ letInsertionTest
        --     standardFilter
        --     "\\(x : Int) (y : Int) -> (((- x) + (- y)) / ((- x) + (- y))) + (- y)"
        --     "\\(x : Int) -> (let b = (- x) in (\\(y : Int) -> (let a = (- y) in (let c = (a + b) in (c / c))) + y))"

        -- Disabled due to bugs in parser
        -- , InsertionTestSpec "insertLiftApp"
        --     appFilter
        --     "- - (1 : Int)"
        --     "let a = 1 in let b = (- (a : Int)) in let c = - b in c"
    ]

data InsertionTestSpec = InsertionTestSpec String SubexprFilter Text Text

type SubexprFilter = CoDBExpr -> Int -> Bool

standardFilter :: SubexprFilter
standardFilter _e q = q > 1

appFilter :: SubexprFilter
appFilter (App {}, _) _ = True
appFilter _ _ = False

letInsertionTest :: InsertionTestSpec -> TestTree
letInsertionTest (InsertionTestSpec testName subexprFilter input expected) =
  unitTestCase testName $ do
    inputExpr <- normTypeClasses =<< parseAndTypeCheckExpr input
    expectedExpr <- normTypeClasses =<< parseAndTypeCheckExpr expected
    result <- insertLets subexprFilter True inputExpr

    -- Need to re-typecheck the result as let-insertion puts a Hole on
    -- each binder type.
    standardLibraryProg <- loadLibrary standardLibrary
    typedResult <- typeCheckExpr [standardLibraryProg] result

    let errorMessage =
          layoutAsString $
            "Expected the result of let lifting"
              <> line
              <> indent 2 (squotes (pretty input))
              <> line
              <> "to be alpha equivalent to"
              <> line
              <> indent 2 (squotes (prettyFriendly $ WithContext expectedExpr emptyDBCtx))
              <> line
              <> "however the result was"
              <> line
              <> indent 2 (squotes (prettyFriendly $ WithContext typedResult emptyDBCtx))

    return $
      assertBool errorMessage $
        alphaEq expectedExpr typedResult
