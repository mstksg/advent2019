{-# Language OverloadedStrings, ScopedTypeVariables, DataKinds #-}
{-|
Module      : Main
Description : Day 22 solution
Copyright   : (c) Eric Mertens, 2019
License     : ISC
Maintainer  : emertens@gmail.com

<https://adventofcode.com/2019/day/22>

-}
module Main (main) where

import Advent                         (Parser, getParsedLines, number)
import Control.Applicative            ((<|>))
import Data.Semigroup                 (stimes)
import GHC.Natural                    (Natural)
import GHC.TypeNats                   (KnownNat, SomeNat(..), someNatVal)
import Math.NumberTheory.Moduli.Class (Mod, invertMod, getNatVal)

data Command
  = Cut     Integer
  | DealInc Integer
  | DealNew
  deriving Show

parseCommand :: Parser Command
parseCommand
    = Cut     <$ "cut " <*> number
  <|> DealInc <$ "deal with increment " <*> number
  <|> DealNew <$ "deal into new stack"

applyCut :: KnownNat n => Mod n -> Mod n -> Mod n
applyCut z i = i+z

applyDealInc :: KnownNat n => Mod n -> Mod n -> Mod n
applyDealInc z i = i*q
  where
    Just q = invertMod z

toComposite :: KnownNat n => Command -> Composite n
toComposite DealNew     = Composite (-1) 1
toComposite (Cut i)     = Composite 1 (fromInteger i)
toComposite (DealInc i) = Composite (fromInteger i) 0

data Composite n = Composite
  { compDealInc :: !(Mod n)
  , compCut     :: !(Mod n)
  }
  deriving Show

apply :: KnownNat n => Composite n -> Mod n -> Mod n
apply c = applyDealInc (compDealInc c)
        . applyCut (compCut c)

compositeCut :: KnownNat n => Mod n -> Composite n -> Composite n
compositeCut x c = c { compCut = compDealInc c * x + compCut c }

compositeDealInc :: KnownNat n => Mod n -> Composite n -> Composite n
compositeDealInc x c = c { compDealInc = x * compDealInc c }

instance KnownNat n => Semigroup (Composite n) where
  x <> y = compositeDealInc (compDealInc x)
         $ compositeCut     (compCut x) y

instance KnownNat n => Monoid (Composite n) where
  mempty = Composite 1 0

main :: IO ()
main =
  do inp <- getParsedLines 22 parseCommand
     print (driver inp           10007               1 2019)
     print (driver inp 119315717514047 101741582076661 2020)

driver :: [Command] -> Natural -> Natural -> Natural -> Natural
driver commands cards iterations index =
  case someNatVal cards of
    SomeNat (_ :: p n) ->
      let single = mconcat (map toComposite commands) :: Composite n
          full   = stimes iterations single
      in getNatVal (apply full (fromIntegral index))
