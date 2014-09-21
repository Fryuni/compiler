{-# OPTIONS_GHC -W #-}
module Parse.Pattern (term, expr) where

import Control.Applicative ((<$>))
import Data.Char (isUpper)
import qualified Data.List as List
import Text.Parsec hiding (newline,spaces,State)

import Parse.Helpers
import Parse.Literal
import AST.Literal
import qualified AST.Pattern as P
import qualified AST.Variable as Var

basic :: IParser P.RawPattern
basic = choice
    [ char '_' >> return P.Anything
    , do v <- var
         return $ case v of
                    "True"          -> P.Literal (Boolean True)
                    "False"         -> P.Literal (Boolean False)
                    c:_ | isUpper c -> P.Data (Var.Raw v) []
                    _               -> P.Var v
    , P.Literal <$> literal
    ]

asPattern :: P.RawPattern -> IParser P.RawPattern
asPattern pattern = do
  var <- optionMaybe (try (whitespace >> reserved "as" >> whitespace >> lowVar))
  return $ case var of
             Just v -> P.Alias v pattern
             Nothing -> pattern

record :: IParser P.RawPattern
record = P.Record <$> brackets (commaSep1 lowVar)

tuple :: IParser P.RawPattern
tuple = do
  ps <- parens (commaSep expr)
  return $ case ps of
             [p] -> p
             _ -> P.tuple ps

list :: IParser P.RawPattern
list = P.list <$> braces (commaSep expr)

term :: IParser P.RawPattern
term =
     (choice [ record, tuple, list, basic ]) <?> "pattern"

patternConstructor :: IParser P.RawPattern
patternConstructor = do
  v <- List.intercalate "." <$> dotSep1 capVar
  case v of
    "True"  -> return $ P.Literal (Boolean True)
    "False" -> return $ P.Literal (Boolean False)
    _       -> P.Data (Var.Raw v) <$> spacePrefix term

expr :: IParser P.RawPattern
expr = do
  patterns <- consSep1 (patternConstructor <|> term)
  asPattern (foldr1 P.cons patterns) <?> "pattern"
