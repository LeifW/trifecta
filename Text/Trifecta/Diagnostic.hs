module Text.Trifecta.Diagnostic 
  ( Diagnostic(..)
  ) where

import Control.Applicative
import Control.Comonad
import Data.Functor.Apply
import Data.Foldable
import Data.Traversable
import Data.Monoid
import Data.List.NonEmpty hiding (map)
import Data.Semigroup
import Data.Semigroup.Foldable
import Data.Semigroup.Traversable
import Data.Maybe (catMaybes)
import Text.Trifecta.Bytes
import Text.Trifecta.Delta
import Text.Trifecta.Util
import Text.Trifecta.Render.Prim
import Text.Trifecta.Diagnostic.Level
import Text.PrettyPrint.Free
import System.Console.Terminfo.PrettyPrint

data Diagnostic m = Diagnostic !Render !DiagnosticLevel m [Diagnostic m]

instance Renderable (Diagnostic m) where
  render (Diagnostic r _ _ _) = r

instance HasDelta (Diagnostic m) where
  delta (Diagnostic r _ _ _) = delta r

instance HasBytes (Diagnostic m) where
  bytes = bytes . delta

instance Extend Diagnostic where
  extend f d@(Diagnostic r l _ xs) = Diagnostic r l (f d) (map (extend f) xs)

instance Comonad Diagnostic where
  extract (Diagnostic _ _ m _) = m

instance Pretty m => Pretty (Diagnostic m) where
  pretty (Diagnostic r l m xs) = vsep $ catMaybes
     [ return $ pretty (delta r) <> char ':' <+> pretty l <> char ':' <+> nest 4 (pretty m)
     , return $ pretty r
     , indent 2 (prettyList xs) <$ guard (not (null xs))
     ]
  prettyList = Prelude.foldr ((<>) . pretty) empty

instance PrettyTerm m => PrettyTerm (Diagnostic m) where
  prettyTerm (Diagnostic r l m xs) = vsep $ catMaybes
     [ return $ prettyTerm (delta r) <> char ':' <+> prettyTerm l <> char ':' <+> nest 4 (prettyTerm m)
     , pretty $ pretty r
     , indent 2 (prettyTermList xs) <$ guard (not (null xs))
     ]
  prettyTermList = Prelude.foldr ((<>) . prettyTerm) empty

instance Pretty m => Show (Diagnostic m) where
  showsPrec d = showsPrec d . pretty

instance Functor Diagnostic where
  fmap f (Diagnostic r l m xs) = Diagnostic r l (f m) $ map (fmap f) xs

instance Foldable Diagnostic where
  foldMap f (Diagnostic _ _ m xs) = f m `mappend` foldMap (foldMap f) xs

instance Traversable Diagnostic where
  traverse f (Diagnostic r l m xs) = Diagnostic r l <$> f m <*> traverse (traverse f) xs

instance Foldable1 Diagnostic where
  foldMap1 f (Diagnostic _ _ m []) = f m
  foldMap1 f (Diagnostic _ _ m (x:xs)) = f m <> foldMap1 (foldMap1 f) (x:|xs)

instance Traversable1 Diagnostic where
  traverse1 f (Diagnostic r l m [])     = fmap (\fm -> Diagnostic r l fm []) (f m)
  traverse1 f (Diagnostic r l m (x:xs)) = (\fm (y:|ys) -> Diagnostic r l fm (y:ys)) 
                                      <$> f m 
                                      <.> traverse1 (traverse1 f) (x:|xs)