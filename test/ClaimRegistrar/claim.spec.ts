import { Contract } from '@ethersproject/contracts'
import { expect } from 'chai'
import { deployments, network, waffle } from 'hardhat'
import { getClaimRegistrarContract } from '../utils/setup'

const setNextBlock = async () => {
  const now = Date.now()
  await network.provider.send('evm_setNextBlockTimestamp', [now])
  await network.provider.send('evm_mine')
  return now
}

describe('ClaimRegistrar', async () => {
  const [connectedUser, user2] = waffle.provider.getWallets()

  const setupTests = deployments.createFixture(async ({ deployments }) => {
    await deployments.fixture()
    return {
      registrar: await getClaimRegistrarContract(),
    }
  })

  describe('claim', async () => {
    const domainClaim = {
      propertyType: 'Domain',
      propertyId: 'example.com',
      evidence: 'example.com',
      method: 'TXT',
    }

    let registrar: Contract
    beforeEach(async () => {
      const contracts = await setupTests()
      registrar = contracts.registrar
      registrar.connect(connectedUser)
      await setNextBlock()
    })

    it('should new a claim', async () => {
      const { propertyType, propertyId, evidence, method } = domainClaim
      await registrar.claim(propertyType, propertyId, evidence, method)

      const [claimKeys] = await registrar.listClaimKeys(connectedUser.address)
      expect(claimKeys).to.have.length(1)
      const res = await registrar.allClaims(claimKeys[0])
      expect(res).to.deep.equal([propertyType, propertyId, evidence, method])
    })
    it('should add a claim', async () => {
      const { propertyType, propertyId, evidence, method } = domainClaim
      await registrar.claim(propertyType, propertyId, evidence, method)
      const anotherId = propertyId + '2'
      await registrar.claim(propertyType, anotherId, evidence, method)

      const [claimKeys] = await registrar.listClaimKeys(connectedUser.address)
      expect(claimKeys).to.have.length(2)
      expect((await registrar.allClaims(claimKeys[0]))[1]).to.deep.equal(
        propertyId
      )
      expect((await registrar.allClaims(claimKeys[1]))[1]).to.deep.equal(
        anotherId
      )
    })
    it('should update a claim if the same key', async () => {
      const { propertyType, propertyId, evidence, method } = domainClaim
      await registrar.claim(propertyType, propertyId, evidence, method)
      const anotherEvidence = evidence + '2'
      await registrar.claim(propertyType, propertyId, anotherEvidence, method)

      const [claimKeys] = await registrar.listClaimKeys(connectedUser.address)
      expect(claimKeys).to.have.length(1)
      expect((await registrar.allClaims(claimKeys[0]))[2]).to.deep.equal(
        anotherEvidence
      )
    })
    it.skip('should new a claim to the same property by another account', async () => {
      const { propertyType, propertyId, evidence, method } = domainClaim
      await registrar.claim(propertyType, propertyId, evidence, method)

      // how to switch user
      const registrar2 = await getClaimRegistrarContract()
      registrar2.connect(user2)
      await registrar2.claim(propertyType, propertyId, evidence, method)

      const [claimKeys1] = await registrar.listClaimKeys(connectedUser.address)
      expect(claimKeys1).to.have.length(1)
      const [claimKeys2] = await registrar.listClaimKeys(user2.address)
      expect(claimKeys2).to.have.length(1)
      expect(claimKeys1[0]).to.not.eq(claimKeys2[0])
    })
    it('fail if property type is blank', async () => {
      const { propertyId, evidence, method } = domainClaim
      await expect(
        registrar.claim('', propertyId, evidence, method)
      ).to.be.revertedWith('CLM001')
    })
    it('fail if property id is blank', async () => {
      const { propertyType, evidence, method } = domainClaim
      await expect(
        registrar.claim(propertyType, '', evidence, method)
      ).to.be.revertedWith('CLM002')
    })
  })
})