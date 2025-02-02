module Vehicle.Verify.Specification.IO
  ( writeSpecificationFiles,
    outputSpecification,
    verifySpecification,
  )
where

import Control.Monad (forM, forM_)
import Control.Monad.IO.Class (MonadIO (..))
import Control.Monad.Reader (MonadReader (..), ReaderT (..))
import Data.Bifunctor (Bifunctor (..))
import Data.Map qualified as Map
import Data.Text (unpack)
import System.Directory (createDirectoryIfMissing)
import System.FilePath (dropExtension, (<.>), (</>))
import Vehicle.Backend.Prelude (Backend (..), writeResultToFile)
import Vehicle.Compile.Prelude
import Vehicle.Compile.Queries
import Vehicle.Verify.Core
import Vehicle.Verify.Specification
import Vehicle.Verify.Specification.Status
import Vehicle.Verify.Verifier.Interface

-- | Writes the queries that make up the specification to individual files in
-- provided folder.
writeSpecificationFiles ::
  MonadIO m =>
  Verifier ->
  FilePath ->
  Specification QueryData ->
  m ()
writeSpecificationFiles Verifier {..} folder (Specification properties) = do
  -- Create the directory to store the queries
  let directory = dropExtension folder
  liftIO $ createDirectoryIfMissing True directory

  let backend = VerifierBackend verifierIdentifier

  -- Write out the spec files
  forM_ properties $ \(ident, property) -> do
    let property' = calculateFilePaths folder ident property
    _ <- flip traverseProperty property' $ \(queryFilePath, queryData) -> do
      let query = queryText queryData
      liftIO $ writeResultToFile backend (Just queryFilePath) query

    return ()

-- | Outputs the specification to IO
outputSpecification ::
  MonadIO m =>
  Specification QueryData ->
  m ()
outputSpecification (Specification properties) = do
  let doc = vsep2 (fmap goProperty properties)
  programOutput doc
  where
    goProperty :: (Identifier, Property QueryData) -> Doc ()
    goProperty (ident, property) = do
      pretty (nameOf ident :: Name)
        <> line
        <> indent 2 (vsep2 (goMultiProperty property))

    goMultiProperty :: Property QueryData -> [Doc ()]
    goMultiProperty = \case
      MultiProperty ps -> concatMap goMultiProperty ps
      SingleProperty p -> do
        let queries = zip [1 ..] (propertyExprToList p)
        fmap goQuery queries

    goQuery :: (QueryID, (NegationStatus, QueryData)) -> Doc ()
    goQuery (queryID, (negated, queryData)) =
      "Query"
        <+> pretty queryID
          <> parens ("negated =" <+> pretty negated)
          <> line
          <> indent 2 (queryText queryData)

--------------------------------------------------------------------------------
-- Verification

-- | Uses the verifier to verify the specification. Failure of one property does
-- not prevent the verification of the other properties.
verifySpecification ::
  MonadIO m =>
  Verifier ->
  VerifierExecutable ->
  FilePath ->
  NetworkLocations ->
  Specification QueryData ->
  m SpecificationStatus
verifySpecification verifier verifierExecutable queryFolder networkLocations spec = do
  let Specification namedProperties = spec
  results <- forM namedProperties $ \(name, property) -> do
    let property' = calculateFilePaths queryFolder name property
    result <- runReaderT (verifyProperty property') (verifier, verifierExecutable, networkLocations)
    return (name, result)
  return $ SpecificationStatus (Map.fromList results)

verifyProperty ::
  (MonadReader (Verifier, VerifierExecutable, NetworkLocations) m, MonadIO m) =>
  Property (QueryFile, QueryData) ->
  m PropertyStatus
verifyProperty = \case
  SingleProperty p -> SinglePropertyStatus <$> foldMPropertyExpr verifyQuery isVerified p
  MultiProperty ps -> MultiPropertyStatus <$> traverse verifyProperty ps

verifyQuery ::
  (MonadReader (Verifier, VerifierExecutable, NetworkLocations) m, MonadIO m) =>
  (QueryFile, QueryData) ->
  m SatisfiabilityStatus
verifyQuery (queryFile, QueryData _ metaNetwork userVar) = do
  (verifier, verifierExecutable, networkLocations) <- ask
  invokeVerifier verifier verifierExecutable networkLocations metaNetwork userVar queryFile

--------------------------------------------------------------------------------
-- Calculation of file paths

-- | Indices into a multi-property.
type MultiPropertyIndex = Int

calculateFilePaths :: FilePath -> Identifier -> Property a -> Property (FilePath, a)
calculateFilePaths directory propertyIdentifier = goProperty []
  where
    goProperty :: [MultiPropertyIndex] -> Property a -> Property (FilePath, a)
    goProperty propertyIndices = \case
      MultiProperty subproperties -> do
        let numberedSubproperties = zip [0 :: QueryID ..] subproperties
        let result = flip fmap numberedSubproperties $ \(i, p) ->
              goProperty (i : propertyIndices) p
        MultiProperty result
      SingleProperty propertyExpr ->
        SingleProperty $ goQuery propertyIndices propertyExpr

    goQuery :: [MultiPropertyIndex] -> PropertyExpr a -> PropertyExpr (FilePath, a)
    goQuery propertyIndices = fmapNumberedPropertyExpr $ first $ \queryID ->
      directory
        </> unpack (nameOf propertyIdentifier)
          <> propertyStr
          <> "-query"
          <> show queryID <.> "txt"
      where
        propertyStr =
          if null propertyIndices
            then ""
            else concatMap (\v -> "!" <> show v) (reverse propertyIndices)
