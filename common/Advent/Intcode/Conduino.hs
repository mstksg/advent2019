{-# Language BlockArguments #-}
module Advent.Intcode.Conduino
  ( -- * Intcode adapters
    intcodePipe, machinePipe, effectPipe,

    -- * Termination condition
    Outcome(..), isOK,

    -- * Run pipe as an effect
    pipeEffect,
  ) where

import Advent.Intcode            (Machine, Effect(..), run, new)
import Control.Monad.Trans.Cont  (Cont, runCont, shift)
import Control.Monad.Trans.Class (lift)
import Control.Monad             (forever)
import Data.Conduino             (Pipe, awaitEither, awaitForever, yield, runPipe, (.|))
import Data.Void                 (Void)


data Outcome = OutcomeOK | OutcomeFault
  deriving (Eq, Ord, Read, Show)

isOK :: Outcome -> Bool
isOK OutcomeOK    = True
isOK OutcomeFault = False

intcodePipe :: [Int] {- ^ intcode -} -> Pipe Int Int Void m Outcome
intcodePipe = machinePipe . new

machinePipe :: Machine -> Pipe Int Int Void m Outcome
machinePipe = effectPipe . run

effectPipe :: Effect -> Pipe Int Int u m Outcome
effectPipe Halt         = return OutcomeOK
effectPipe Fault        = return OutcomeFault
effectPipe (Output o e) = yield o >> effectPipe e
effectPipe (Input  f  ) =
  do e <- awaitEither
     case e of
       Left _  -> return OutcomeFault
       Right x -> effectPipe (f x)

pipeEffect :: Pipe Int Int u (Cont Effect) Outcome -> Effect
pipeEffect pipe = runCont (runPipe (inputs .| pipe .| outputs)) finish
  where
    finish OutcomeOK    = Halt
    finish OutcomeFault = Fault

    outputs :: Pipe Int o a (Cont Effect) a
    outputs = awaitForever \o -> lift $ shift \k -> return $ Output o $ k ()

    inputs :: Pipe i Int u (Cont Effect) a
    inputs =
      forever
        do i <- lift $ shift \k -> return $ Input k
           yield i
