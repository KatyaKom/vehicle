module Vehicle.Backend.Prelude where

import Data.Text (Text)
import Data.Text.IO qualified as TIO
import Data.Bifunctor (Bifunctor(first))
import Data.Version (Version, makeVersion)
import System.FilePath (takeDirectory)
import System.Directory (createDirectoryIfMissing)

import Vehicle.Prelude
import Paths_vehicle qualified as VehiclePath

data Backend
  = ITP ITP
  | Verifier Verifier
  | LossFunction
  | TypeCheck
  deriving (Eq, Show)

data ITP
  = Agda
  deriving (Eq, Show, Read)

data Verifier
  = Marabou
  deriving (Eq, Show, Read)

instance Pretty Verifier where
  pretty = pretty . show

verifierExecutableName :: Verifier -> String
verifierExecutableName = \case
  Marabou -> "marabou"

magicVariablePrefixes :: Verifier -> (Text, Text)
magicVariablePrefixes Marabou = ("x", "y")

pattern AgdaBackend :: Backend
pattern AgdaBackend = ITP Agda

pattern MarabouBackend :: Backend
pattern MarabouBackend = Verifier Marabou

instance Pretty Backend where
  pretty = \case
    ITP x         -> pretty $ show x
    Verifier x    -> pretty $ show x
    LossFunction  -> "LossFunction"
    TypeCheck     -> "TypeCheck"

instance Read Backend where
  readsPrec d x =
    case readsPrec d x of
      [] -> case readsPrec d x of
        []  -> []
        res -> fmap (first Verifier) res
      res -> fmap (first ITP) res

commentTokenOf :: Backend -> Maybe (Doc a)
commentTokenOf = \case
  Verifier Marabou -> Nothing
  ITP Agda         -> Just "--"
  LossFunction     -> Nothing
  TypeCheck        -> Nothing

versionOf :: Backend -> Maybe Version
versionOf target = case target of
  Verifier Marabou -> Nothing
  ITP Agda         -> Just $ makeVersion [2,6,2]
  LossFunction     -> Nothing
  TypeCheck        -> Nothing

extensionOf :: Backend -> String
extensionOf = \case
  Verifier Marabou -> "-marabou"
  ITP Agda         -> ".agda"
  LossFunction     -> ".json"
  TypeCheck        -> ""

-- |Generate the file header given the token used to start comments in the
-- target language
prependfileHeader :: Doc a -> Backend -> Doc a
prependfileHeader doc target = case commentTokenOf target of
  Nothing           -> doc
  Just commentToken -> vsep (map (commentToken <+>)
    [ "WARNING: This file was generated automatically by Vehicle"
    , "and should not be modified manually!"
    , "Metadata"
    , " -" <+> pretty target <> " version:" <+> targetVersion
    , " - AISEC version:" <+> pretty VehiclePath.version
    , " - Time generated: ???"
    ]) <> line <> line <> doc
  where targetVersion = maybe "N/A" pretty (versionOf target)

writeResultToFile :: Backend -> Maybe FilePath -> Doc a -> IO ()
writeResultToFile target filepath doc = do
  let text = layoutAsText $ prependfileHeader doc target
  case filepath of
    Nothing             -> TIO.putStrLn text
    Just outputFilePath -> do
      createDirectoryIfMissing True (takeDirectory outputFilePath)
      TIO.writeFile outputFilePath text