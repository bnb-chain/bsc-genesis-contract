import { Wallet } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { BSCValidatorSet } from '../../typechain-types/BscValidatorSet'
import { SlashIndicator } from '../../typechain-types/SlashIndicator'
import { expect } from "chai";
const log = console.log
const createFixtureLoader = waffle.createFixtureLoader

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T

describe('BSCValidatorSet', () => {
  let wallet: Wallet, other: Wallet

  before('before', async () => {
    ;[wallet, other] = await (ethers as any).getSigners()

  })

  beforeEach('beforeEach', async () => {

  })

  it('test init', async () => {
    log('test')
  })
})
