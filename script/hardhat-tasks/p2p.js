const fetch = require('node-fetch');
const log = require("../utils/logger")("task:p2p");

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
const operateValidators = async ({ store, signer, nodeDelegator }) => {
  /*  Holds current request context containing: 
   *   - UUID
   *   - number of validators requested
   *   - contracts
   */
  const context = {}


  // check if any validator requests are pending
};

/* Each P2P request has a life cycle that results in the following states stored
 * in the shared Defender key-value storage memory. 
 *  - "cluster_formation_issued" the create request that forms the cluster issued
 *  - "cluster_formation_confirmed" the cluster formation has been confirmed, cluster is ready
 *  - "register_transaction_broadcast" the transaction to register validators on the SSV network 
 *    has been broadcast to the network
 *  - "cluster_registered" the register transaction has been confirmed
 *  - "deposit_transaction_broadcast" the stake transaction staking 32 ETH per validator
 *    has been broadcast to the network
 *  - "deposit_confirmed" transaction to stake 32 ETH per validator has been confirmed
 */
const updateState = async (requestUUID, state) => {
  
};

// How many validators are viable considering (W)ETH balance of the NodeDelegators
const numberOfValidatorsAllowed = async (context) => {

}

const createValidators = async (options) => {
  const store = new KeyValueStoreClient(event);
  //await store.put('myKey', 'myValue');
  //const value = await store.get('myKey');
  //await store.del('myKey');
  
//   const response = await fetch('https://api-test.p2p.org/api/v1/eth/staking/direct/nodes-request/create',
//     {
//       method: 'POST',
//       headers: {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//         'Authorization': 'Bearer DmoIpUsQmHoQ6rnfSQpFyOQDspt9AJSQ'
//       },
//       body: JSON.stringify({
//         "validatorsCount": 1,
//         "nodesOptions": {
//           "location": "any"
//         },
//         "id": "dd195c88-4cdb-440b-a562-497dd3f00125",
//         "type": "RESTAKING",
//         "eigenPodOwnerAddress": "0x1048A97Dcd55ae9833E01FBEEbFA3949C6AcC3FE"
//       }),
//     }
//   );
// 
//   const body = await response.text();
// 
//   console.log("RESPONSE", body);

};

module.exports = {
  createValidators,
  operateValidators,
};
