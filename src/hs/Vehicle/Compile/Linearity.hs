module Vehicle.Compile.Linearity
  ( module X
  , solveForUserVariables
  ) where

import Data.List (partition)
import Data.Set qualified as Set (difference, fromList)
import Data.Vector.Unboxed qualified as Vector

import Vehicle.Compile.Error
import Vehicle.Compile.Prelude
import Vehicle.Compile.Linearity.Core as X
import Vehicle.Compile.Linearity.GaussianElimination (gaussianElimination)
import Vehicle.Compile.Linearity.FourierMotzkinElimination (fourierMotzkinElimination)
import Data.Bifunctor

solveForUserVariables :: MonadCompile m => Int -> CLSTProblem -> m CLSTProblem
solveForUserVariables numberOfUserVars (CLSTProblem varNames assertions) =
  logCompilerPass currentPass $ do
    let allUserVars = Set.fromList [0..numberOfUserVars-1]

    -- First remove those assertions that don't have any user variables in them.
    let (withUserVars, withoutUserVars) =
          partition (hasUserVariables numberOfUserVars) assertions

    -- Then split out the equalities from the inequalities.
    let (equalitiesWithUserVars, inequalitiesWithUserVars) =
          partition isEquality withUserVars

    -- Try to solve for user variables using Gaussian elimination.
    (solvedEqualityExprs, unusedEqualityExprs) <-
      gaussianElimination varNames (map assertionExpr equalitiesWithUserVars) numberOfUserVars
    let unusedEqualities = fmap (Assertion Equals) unusedEqualityExprs
    let gaussianElimSolutions = fmap (second RecEquality) solvedEqualityExprs

    -- Eliminate the solved user variables in the inequalities
    let reducedInequalities =
          flip fmap inequalitiesWithUserVars $ \assertion ->
            foldl (uncurry . substitute) assertion solvedEqualityExprs

    -- Calculate the set of unsolved user variables
    let varsSolvedByGaussianElim = Set.fromList (fmap fst solvedEqualityExprs)
    let varsUnsolvedByGaussianElim = Set.difference allUserVars varsSolvedByGaussianElim

    -- Eliminate the remaining unsolved user vars using Fourier-Motzkin elimination
    (fmElimSolutions, fmElimOutputInequalities) <-
      fourierMotzkinElimination varNames varsUnsolvedByGaussianElim reducedInequalities

    -- Calculate the way to reconstruct the user variables
    let _solutions = fmElimSolutions <> gaussianElimSolutions

    -- Calculate the final set of (user-variable free) assertions
    let finalAssertions = withoutUserVars <> unusedEqualities <> fmElimOutputInequalities

    -- Return the problem
    return (CLSTProblem varNames finalAssertions)

hasUserVariables :: Int -> Assertion -> Bool
hasUserVariables numberOfUserVariables (Assertion _ (LinearExpr e)) =
  let userCoefficients = Vector.take numberOfUserVariables e in
  Vector.any (/= 0) userCoefficients

substitute :: Assertion -> LinearVar -> LinearExpr -> Assertion
substitute (Assertion r2 (LinearExpr e2)) var (LinearExpr e1) =
  let coeff = e2 Vector.! var in
  let e2'  = Vector.zipWith (\a b -> b - coeff * a) e1 e2 in
  Assertion r2 (LinearExpr e2')

currentPass :: Doc ()
currentPass = "elimination of user variables"