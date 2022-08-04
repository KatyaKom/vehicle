module Vehicle.Test.CompileMode.Error
  ( functionalityTests
  ) where

import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.IO qualified as T
import Data.Bifunctor (first)
import Data.Functor ((<&>))
import Data.Map ( Map )
import Data.Map qualified as Map
import System.Exit (exitFailure, ExitCode)
import System.FilePath (takeFileName, splitPath, (<.>), (</>), takeBaseName)
import System.Directory (removeFile, removeDirectory)
import System.IO.Error (isDoesNotExistError)
import System.IO (stderr)
import Control.Exception ( catch, throwIO, SomeException, Exception )
import Data.Maybe (fromMaybe)
import Control.Monad.RWS.Lazy (when)
import Test.Tasty
import Test.Tasty.Golden.Advanced (goldenTest)

import Vehicle
import Vehicle.Prelude
import Vehicle.Compile
import Vehicle.Backend.Prelude

import Vehicle.Test.Utils

--------------------------------------------------------------------------------
-- Tests

functionalityTests :: MonadTest m => m TestTree
functionalityTests = testGroup "ErrorTests" <$> sequence
  [ argumentErrors
  , typeCheckingErrors
  , networkErrors
  , datasetErrors
  , parameterErrors
  , linearityErrors
  , polarityErrors
  ]

argumentErrors :: MonadTest m => m TestTree
argumentErrors = failTestGroup "ArgumentErrors"
  [ testSpec
    { testName     = "missingInputFile"
    , testLocation = Tests
    , testTargets  = [MarabouBackend]
    }
  ]

typeCheckingErrors :: MonadTest m => m TestTree
typeCheckingErrors = failTestGroup "TypingErrors"
  [ testSpec
    { testName     = "intAsNat"
    , testLocation = Tests
    , testTargets  = [TypeCheck]
    }

  , testSpec
    { testName     = "indexOutOfBoundsConcrete"
    , testLocation = Tests
    , testTargets  = [TypeCheck]
    }

  , testSpec
    { testName     = "indexOutOfBoundsUnknown"
    , testLocation = Tests
    , testTargets  = [TypeCheck]
    }

  , testSpec
    { testName     = "incorrectTensorLength"
    , testLocation = Tests
    , testTargets  = [TypeCheck]
    }

  , testSpec
    { testName     = "unsolvedMeta"
    , testLocation = Tests
    , testTargets  = [TypeCheck]
    }
  ]

networkErrors :: MonadTest m => m TestTree
networkErrors = failTestGroup "NetworkErrors"
  [ testSpec
    { testName     = "notAFunction"
    , testLocation = Tests
    , testTargets  = [TypeCheck]
    }
  ]

datasetErrors :: MonadTest m => m TestTree
datasetErrors = failTestGroup "DatasetErrors"
  [ testSpec
    { testName     = "notProvided"
    , testLocation = Tests
    , testTargets  = [MarabouBackend]
    , testDatasets = []
    }

  , testSpec
    { testName     = "missingDataset"
    , testLocation = Tests
    , testTargets  = [MarabouBackend]
    , testDatasets = [("trainingDataset", "non-existent.idx")]
    }

  , testSpec
    { testName     = "unsupportedFormat"
    , testLocation = Tests
    , testTargets  = [MarabouBackend]
    , testDatasets = [("trainingDataset", "non-existent.fgt")]
    }

  , testSpec
    { testName     = "invalidContainerType"
    , testLocation = Tests
    , testTargets  = [TypeCheck]
    , testDatasets = [("trainingDataset", "dataset-nat-4.idx")]
    }

  , testSpec
    { testName     = "invalidElementType"
    , testLocation = Tests
    , testTargets  = [TypeCheck]
    , testDatasets = [("trainingDataset", "dataset-nat-4.idx")]
    }

  , testSpec
    { testName     = "variableDimensions"
    , testLocation = Tests
    , testTargets  = [MarabouBackend]
    , testDatasets = [("trainingDataset", "dataset-nat-4.idx")]
    }

  , testSpec
    { testName     = "mismatchedDimensions"
    , testLocation = Tests
    , testTargets  = [MarabouBackend]
    , testDatasets = [("trainingDataset", "dataset-nat-4.idx")]
    }

  , testSpec
    { testName     = "mismatchedDimensionSize"
    , testLocation = Tests
    , testTargets  = [MarabouBackend]
    , testDatasets = [("trainingDataset", "dataset-nat-4.idx")]
    }

  , testSpec
    { testName     = "mismatchedType"
    , testLocation = Tests
    , testTargets  = [MarabouBackend]
    , testDatasets = [("trainingDataset", "dataset-rat-4.idx")]
    }

  , testSpec
    { testName     = "tooBigIndex"
    , testLocation = Tests
    , testTargets  = [MarabouBackend]
    , testDatasets = [("trainingDataset", "dataset-nat-4.idx")]
    }

  , testSpec
    { testName     = "negativeNat"
    , testLocation = Tests
    , testTargets  = [MarabouBackend]
    , testDatasets = [("trainingDataset", "dataset-int-4.idx")]
    }
  ]

parameterErrors :: MonadTest m => m TestTree
parameterErrors = failTestGroup "ParameterErrors"
  [ testSpec
    { testName       = "notProvided"
    , testLocation   = Tests
    , testTargets    = [MarabouBackend]
    , testParameters = []
    }

  , testSpec
    { testName       = "unsupportedType"
    , testLocation   = Tests
    , testTargets    = [TypeCheck]
    }

  , testSpec
    { testName       = "unparseableBool"
    , testLocation   = Tests
    , testTargets    = [MarabouBackend]
    , testParameters = [("b", "x")]
    }

  , testSpec
    { testName       = "unparseableIndex"
    , testLocation   = Tests
    , testTargets    = [MarabouBackend]
    , testParameters = [("n", "~`")]
    }

  , testSpec
    { testName       = "invalidIndex"
    , testLocation   = Tests
    , testTargets    = [MarabouBackend]
    , testParameters = [("n", "5")]
    }

  , testSpec
    { testName       = "invalidNat"
    , testLocation   = Tests
    , testTargets    = [MarabouBackend]
    , testParameters = [("n", "-5")]
    }

  , testSpec
    { testName       = "unparseableNat"
    , testLocation   = Tests
    , testTargets    = [MarabouBackend]
    , testParameters = [("n", "~`")]
    }

  , testSpec
    { testName       = "unparseableRat"
    , testLocation   = Tests
    , testTargets    = [MarabouBackend]
    , testParameters = [("r", "~`")]
    }
  ]

polarityErrors :: MonadTest m => m TestTree
polarityErrors = failTestGroup "PolarityErrors"
  [ testSpec
      { testName       = "mixedSequential"
      , testLocation   = Tests
      , testTargets    = [MarabouBackend]
      , testParameters = []
      }

  , testSpec
      { testName       = "mixedNegSequential"
      , testLocation   = Tests
      , testTargets    = [MarabouBackend]
      , testParameters = []
      }

  , testSpec
    { testName       = "mixedNegNegSequential"
    , testLocation   = Tests
    , testTargets    = [MarabouBackend]
    , testParameters = []
    }

  , testSpec
    { testName       = "mixedImpliesSequential"
    , testLocation   = Tests
    , testTargets    = [MarabouBackend]
    , testParameters = []
    }

  , testSpec
    { testName       = "mixedFunSequential"
    , testLocation   = Tests
    , testTargets    = [MarabouBackend]
    , testParameters = []
    }
  ]

linearityErrors :: MonadTest m => m TestTree
linearityErrors = failTestGroup "LinearityErrors"
  [ testSpec
      { testName       = "quadraticInput"
      , testLocation   = Tests
      , testTargets    = [MarabouBackend]
      , testParameters = []
      }

  , testSpec
      { testName       = "quadraticFunInput"
      , testLocation   = Tests
      , testTargets    = [MarabouBackend]
      , testParameters = []
      }

  , testSpec
      { testName       = "quadraticFunOutput"
      , testLocation   = Tests
      , testTargets    = [MarabouBackend]
      , testParameters = []
      }

  , testSpec
      { testName       = "quadraticInputOutput"
      , testLocation   = Tests
      , testTargets    = [MarabouBackend]
      , testParameters = []
      }

  , testSpec
      { testName       = "quadraticTensorInputLookup"
      , testLocation   = Tests
      , testTargets    = [MarabouBackend]
      , testParameters = []
      }
  ]

--------------------------------------------------------------------------------
-- Test infrastructure

testDir :: FilePath
testDir = baseTestDir </> "CompileMode" </> "Error"

failTestGroup :: MonadTest m
              => FilePath
              -> [TestSpec]
              -> m TestTree
failTestGroup folder tests = testGroup folder <$> traverse mkTest tests
  where
  mkTest spec@TestSpec{..} = do
    let resources = testResources spec
    failTest (folder </> testName) (head testTargets) resources

failTest :: MonadTest m => FilePath -> Backend -> Resources -> m TestTree
failTest filepath backend resources = do
  loggingSettings <- getTestLoggingSettings

  let testName       = takeBaseName filepath
  let basePath       = testDir </> filepath
  let inputFile      = basePath <.> ".vcl"
  let logFile        = basePath <> "-temp" <.> "txt"
  let goldenFile     = basePath <.> "txt"
  let run            = runTest loggingSettings inputFile logFile backend resources

  return $ goldenFileTest testName run omitFilePaths goldenFile logFile

runTest :: TestLoggingSettings
        -> FilePath
        -> FilePath
        -> Backend
        -> Resources
        -> IO ()
runTest (logFile, debugLevel) inputFile outputFile backend Resources{..} = do
  run options `catch` handleExitCode
  where
  options = Options
    { version     = False
    , outFile     = Nothing
    , errFile     = Just outputFile
    , logFile     = logFile
    , debugLevel  = debugLevel
    , modeOptions = Compile $ CompileOptions
      { target            = backend
      , specificationFile = inputFile
      , outputFile        = Nothing
      , networkLocations  = networks
      , datasetLocations  = datasets
      , parameterValues   = parameters
      , modulePrefix      = Nothing
      , proofCache        = Nothing
      }
    }

handleExitCode :: ExitCode -> IO ()
handleExitCode e = return ()