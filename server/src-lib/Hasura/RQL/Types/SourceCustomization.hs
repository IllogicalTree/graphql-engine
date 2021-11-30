{-# LANGUAGE UndecidableInstances #-}

module Hasura.RQL.Types.SourceCustomization
  ( MkTypename (..),
    SourceTypeCustomization,
    RootFieldsCustomization (..),
    mkCustomizedTypename,
    emptySourceCustomization,
    getSourceTypeCustomization,
    getRootFieldsCustomization,
    mkRootFieldName,
    SourceCustomization (..),
    withSourceCustomization,
    MkRootFieldName,
    CustomizeRemoteFieldName (..),
    withRemoteFieldNameCustomization,
  )
where

import Control.Lens
import Data.Aeson.Extended
import Data.Has
import Data.Monoid
import Hasura.GraphQL.Parser.Schema
import Hasura.Incremental.Internal.Dependency (Cacheable)
import Hasura.Prelude
import Hasura.RQL.Types.Instances ()
import Language.GraphQL.Draft.Syntax qualified as G

data RootFieldsCustomization = RootFieldsCustomization
  { _rootfcNamespace :: !(Maybe G.Name),
    _rootfcPrefix :: !(Maybe G.Name),
    _rootfcSuffix :: !(Maybe G.Name)
  }
  deriving (Eq, Show, Generic)

instance Cacheable RootFieldsCustomization

instance ToJSON RootFieldsCustomization where
  toJSON = genericToJSON hasuraJSON

instance FromJSON RootFieldsCustomization where
  parseJSON = genericParseJSON hasuraJSON

emptyRootFieldsCustomization :: RootFieldsCustomization
emptyRootFieldsCustomization = RootFieldsCustomization Nothing Nothing Nothing

data SourceTypeCustomization = SourceTypeCustomization
  { _stcPrefix :: !(Maybe G.Name),
    _stcSuffix :: !(Maybe G.Name)
  }
  deriving (Eq, Show, Generic)

instance Cacheable SourceTypeCustomization

instance ToJSON SourceTypeCustomization where
  toJSON = genericToJSON hasuraJSON

instance FromJSON SourceTypeCustomization where
  parseJSON = genericParseJSON hasuraJSON

emptySourceTypeCustomization :: SourceTypeCustomization
emptySourceTypeCustomization = SourceTypeCustomization Nothing Nothing

mkCustomizedTypename :: Maybe SourceTypeCustomization -> MkTypename
mkCustomizedTypename Nothing = mempty
mkCustomizedTypename (Just SourceTypeCustomization {..}) =
  MkTypename (applyPrefixSuffix _stcPrefix _stcSuffix)

mkCustomizedFieldName :: Maybe RootFieldsCustomization -> MkRootFieldName
mkCustomizedFieldName Nothing = mempty
mkCustomizedFieldName (Just RootFieldsCustomization {..}) =
  MkRootFieldName (applyPrefixSuffix _rootfcPrefix _rootfcSuffix)

applyPrefixSuffix :: Maybe G.Name -> Maybe G.Name -> G.Name -> G.Name
applyPrefixSuffix Nothing Nothing name = name
applyPrefixSuffix (Just prefix) Nothing name = prefix <> name
applyPrefixSuffix Nothing (Just suffix) name = name <> suffix
applyPrefixSuffix (Just prefix) (Just suffix) name = prefix <> name <> suffix

data SourceCustomization = SourceCustomization
  { _scRootFields :: !(Maybe RootFieldsCustomization),
    _scTypeNames :: !(Maybe SourceTypeCustomization)
  }
  deriving (Eq, Show, Generic)

instance Cacheable SourceCustomization

instance ToJSON SourceCustomization where
  toJSON = genericToJSON hasuraJSON

instance FromJSON SourceCustomization where
  parseJSON = genericParseJSON hasuraJSON

emptySourceCustomization :: SourceCustomization
emptySourceCustomization = SourceCustomization Nothing Nothing

getRootFieldsCustomization :: SourceCustomization -> RootFieldsCustomization
getRootFieldsCustomization = fromMaybe emptyRootFieldsCustomization . _scRootFields

getSourceTypeCustomization :: SourceCustomization -> SourceTypeCustomization
getSourceTypeCustomization = fromMaybe emptySourceTypeCustomization . _scTypeNames

-- | Function to apply root field name customizations.
newtype MkRootFieldName = MkRootFieldName {runMkRootFieldName :: G.Name -> G.Name}
  deriving (Semigroup, Monoid) via (Endo G.Name)

-- | Inject a new root field name customization function into the environment.
-- This can be used by schema-building code (with @MonadBuildSchema@ constraint) to ensure
-- the correct root field name customizations are applied.
withRootFieldNameCustomization :: forall m r a. (MonadReader r m, Has MkRootFieldName r) => MkRootFieldName -> m a -> m a
withRootFieldNameCustomization = local . set hasLens

-- | Apply the root field name customization function from the current environment.
mkRootFieldName :: (MonadReader r m, Has MkRootFieldName r) => G.Name -> m G.Name
mkRootFieldName name =
  ($ name) . runMkRootFieldName <$> asks getter

-- | Inject typename and root field name customizations from @SourceCustomization@ into
-- the environment.
withSourceCustomization ::
  forall m r a.
  (MonadReader r m, Has MkTypename r, Has MkRootFieldName r) =>
  SourceCustomization ->
  m a ->
  m a
withSourceCustomization SourceCustomization {..} =
  withTypenameCustomization (mkCustomizedTypename _scTypeNames)
    . withRootFieldNameCustomization (mkCustomizedFieldName _scRootFields)

newtype CustomizeRemoteFieldName = CustomizeRemoteFieldName
  { runCustomizeRemoteFieldName :: G.Name -> G.Name -> G.Name
  }
  deriving (Semigroup, Monoid) via (G.Name -> Endo G.Name)

withRemoteFieldNameCustomization :: forall m r a. (MonadReader r m, Has CustomizeRemoteFieldName r) => CustomizeRemoteFieldName -> m a -> m a
withRemoteFieldNameCustomization = local . set hasLens
