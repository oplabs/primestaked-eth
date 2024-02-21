const fetch = require('node-fetch');
const log = require("../utils/logger")("task:p2p");
const { v4: uuidv4 } = require('uuid');
const { BigNumber, utils } = require('ethers')

/*
 * Spawns and maintains the required amount of validators throughout 
 * their setup cycle which consists of: 
 *   - check balance of (W)ETH and crate P2P SSV cluster creation request
 *   - wait for the cluster to become operational
 *   - batch register the cluster on the SSV network
 *   - verify the complete cluster has been registered
 *   - batch stake the ETH to each of the validators
 *
 * Needs to also handle: 
 *   - if anytime in the spawn cycle the number of (W)ETH falls below the 
 *     required stake amount (withdrawal from Node Operator), mark the spawn 
 *     process as failed
 *   - if spawn process gets stuck at any of the above steps and is not able to 
 *     recover in X amount of times (e.g. 5 times). Mark the process as failed 
 *     and start over.
 */
const operateValidators = async ({ store, signer, contracts, config }) => {
  const { p2p_api_key, validatorSpawnOperationalPeriodInDays } = config
  let currentState = await getState(store)
  log("currentState", currentState);

  // TODO: uncomment lines below
  // if (!(await nodeDelegatorHas32Eth(contracts))) {
  //   log(`Node delegator doesn't have enough ETH, exiting`)
  //   return
  // }

  while(true) {
    if (currentState === undefined) {
      await createValidatorRequest(
        p2p_api_key, // api key
        contracts.nodeDelegator.address, // node delegator address
        contracts.nodeDelegator.address, // eigenPod address
        validatorSpawnOperationalPeriodInDays,
        store
      )
      currentState = await getState(store)
    }

    if (currentState.state === 'validator_creation_issued') {
      await confirmValidatorCreatedRequest(
        p2p_api_key,
        currentState.uuid,
        store
      )
    }

    // TODO: change to if deposit confirmed
    if (true) {
      break;
    }
  }
};

/* Each P2P request has a life cycle that results in the following states stored
 * in the shared Defender key-value storage memory. 
 *  - "validator_creation_issued" the create request that creates a validator issued
 *  - "validator_creation_confirmed" confirmation that the validator has been created
 *  - "register_transaction_broadcast" the transaction to register the validator on 
 *    the SSV network has been broadcast to the Ethereum network
 *  - "validator_registered" the register transaction has been confirmed
 *  - "deposit_transaction_broadcast" the stake transaction staking 32 ETH has been
 *    broadcast to the Ethereum network
 *  - "deposit_confirmed" transaction to stake 32 ETH has been confirmed
 */
const updateState = async (requestUUID, state, store, metadata = {}) => {
  if (![
    'validator_creation_issued',
    'validator_creation_confirmed',
    'register_transaction_broadcast',
    'validator_registered',
    'deposit_transaction_broadcast',
    'deposit_confirmed',
    ].includes(state)) {
    throw new Error(`Unexpected state: ${state}`)
  }

  await store.put('currentRequest', JSON.stringify({
    'uuid': requestUUID,
    'state': state,
    metadata
  }))
};

/* Fetches the state of the current/ongoing cluster creation if there is any
 * returns either:
 *  - false if there is no cluster
 *  - 
 */
const getState = async (store) => {
  const currentState = await store.get('currentRequest')
  if (currentState === undefined) {
    return currentState
  }

  return JSON.parse(await store.get('currentRequest'))
}

const nodeDelegatorHas32Eth = async (contracts) => {
  const address = contracts.nodeDelegator.address
  const wethBalance = await contracts.WETH.balanceOf(address)
  const ethBalance = await contracts.nodeDelegator.provider.getBalance(address)
  const totalBalance = wethBalance.add(ethBalance)

  log(`Node delegator has ${utils.formatUnits(totalBalance, 18)} ETH in total`)
  return wethBalance.add(ethBalance).gte(BigNumber.from("32000000000000000000"))
}

/* Make a GET or POST request to P2P service
 * @param api_key: p2p service api key
 * @param method: http method that can either be POST or GET
 * @param body: body object in case of a POST request 
 */
const p2pRequest = async (url, api_key, method, body) => {
  const headers = {
    'Accept': 'application/json',
    'Authorization': `Bearer ${api_key}`
  }

  if (method === 'POST') {
    headers['Content-Type'] = 'application/json'
  }

  const bodyString = JSON.stringify(body);
  log(`Creating a P2P ${method} request with body: ${bodyString}`)

  const rawResponse = await fetch(url,
    {
      method,
      headers,
      body: bodyString,
    }
  );

  const response = await rawResponse.json()
  if (response.error != null) {
    log("Request to P2P service failed with an error:", response)
    throw new Error('Call to P2P has failed');
  } else {
    log("Request to P2P service succeeded: ", response)
  }

  return response
};


const createValidatorRequest = async (p2p_api_key, nodeDelegatorAddress, eigenPodAddress, validatorSpawnOperationalPeriodInDays, store) => {
  const uuid = uuidv4()
  await p2pRequest(
    // TODO these should be mainnet configurable
    'https://api-test.p2p.org/api/v1/eth/staking/ssv/request/create',
    p2p_api_key,
      'POST', {
      "validatorsCount": 1,
      "id": uuid,
      "withdrawalAddress": eigenPodAddress,
      "feeRecipientAddress": nodeDelegatorAddress,
      "ssvOwnerAddress": nodeDelegatorAddress,
      "type": "without-encrypt-key",
      "operationPeriodInDays": validatorSpawnOperationalPeriodInDays

    })

  await updateState(uuid, 'validator_creation_issued', store)
};


const confirmValidatorCreatedRequest = async (p2p_api_key, uuid, store) => {
  const response = await p2pRequest(
    // TODO these should be mainnet configurable
    `https://api-test.p2p.org/api/v1/eth/staking/ssv/request/status/${uuid}`,
    p2p_api_key,
    'GET'
  )

  log("response", response)
  //await updateState(uuid, 'validator_creation_issued', store)
};


module.exports = {
  operateValidators,
};
