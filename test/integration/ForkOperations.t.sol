// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { PrimeZapper } from "contracts/utils/PrimeZapper.sol";
import { Cluster } from "contracts/interfaces/ISSVNetwork.sol";
import { PrimeStakedETH } from "contracts/PrimeStakedETH.sol";
import { LRTConfig } from "contracts/LRTConfig.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { NodeDelegatorLST } from "contracts/NodeDelegatorLST.sol";
import { NodeDelegatorETH } from "contracts/NodeDelegatorETH.sol";
import { Addresses } from "contracts/utils/Addresses.sol";

/**
 * @notice Used to test operational functions against a forked chain.
 * eg registerSsvValidator and stakeEth
 * This is not run as part of the fork tests.
 */
contract ForkOperations is Test {
    LRTDepositPool public lrtDepositPool;
    PrimeStakedETH public preth;
    LRTOracle public lrtOracle;
    LRTConfig public lrtConfig;
    NodeDelegatorLST public nodeDelegator1;
    NodeDelegatorETH public nodeDelegator2;
    PrimeZapper public primeZapper;

    event ETHStaked(bytes valPubKey, uint256 amount);

    function setUp() public virtual {
        string memory url = vm.envString("FORK_RPC_URL");
        vm.createSelectFork(url);

        lrtDepositPool = LRTDepositPool(payable(Addresses.LRT_DEPOSIT_POOL));
        lrtOracle = LRTOracle(Addresses.LRT_ORACLE);
        lrtConfig = LRTConfig(Addresses.LRT_CONFIG);
        nodeDelegator1 = NodeDelegatorLST(Addresses.NODE_DELEGATOR);
        nodeDelegator2 = NodeDelegatorETH(payable(Addresses.NODE_DELEGATOR_NATIVE_STAKING));
        primeZapper = PrimeZapper(payable(Addresses.PRIME_ZAPPER));
    }

    function test_registerValidatorHardcoded() public {
        vm.startPrank(Addresses.OPERATOR_ROLE);

        (uint256 ndcEthBefore, uint256 eigenEthBefore) = nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);

        bytes memory publicKey =
            hex"8e7e5917b8f076f19a6671ed1639d375f2a8a3134efba01215943e3665b7e2e1a688d0e3367092ec3e31b381c104d378";
        uint64[] memory operatorIds = new uint64[](4);
        operatorIds[0] = 192;
        operatorIds[1] = 195;
        operatorIds[2] = 200;
        operatorIds[3] = 201;
        bytes memory sharesData =
        // solhint-disable-next-line max-line-length
            hex"985e6e0b7960ba4e6b27c836b856b174173a7725376ce73abdcb041691a31d4bc9eb8abcb3ea04e528d9c226f80ed266186740979559900b3354f6aa20d0b051071df7397ec4294dbc05d0f1d9dd4807e8f8950b8876c684f0505fb9129fb5d5b3c6a1d1479416ab93e28bf5cd8cad9449f5b5dbd69e462262b6f12f0b20a1ce5148313b35491254e7f8122ce66b869897a2d0d5d76976092e8c260526a6a4a97bae85b7b1d6cc2a8bbd0ce039aa8ee9b0127ccce69657ec704cfc81a5f9d707b17f7d1166e42d2175b6b2111a3489cedc14e0161805dba849806474469d02f07aeb3452a18c281bbd7e7d6d84f86d7e81f126bd9263c460eb103c4f5b172b6ebd87f6d0d8596455a09e18102f8ae4fb723cccb278ea07fb2f3b99dce4162adb865b564ee531f7bc2e2835c879e56d587d57b664136b53ca4dcb28ea552cc68e4d2ce899decddd523797b6f0e8b8d81e8d7a623835649385b0642a47a22943ea3d4d77961e738ddd0efb9e7edbd37cf6c64e44e5d01a6ebfe42b92ad066c69d7a502af6dbd6a46b1f3eab72aee909951937ee3273ffc061870cacd07630998d47a0682fbfd5344dd0e53d28d0df0b1e0506c36d8c9ce0c48767b9fb6b2226781d9d587406ed28a281055a25f4753410c51caeba808aeec8fa5f6e32b40684201e977bd4f4f22acf80c998e40ab5bc51350713fa6acc33898e037130a5533664c63cdd92355c12a748680db1792cae173f65990163c205ede4e73e62f64fd0f218e42ca57f30aa309f9223e4cc06a910db636bcce112d9c5bd526dab8ebd85e717cd2e7155911f79f390bdddfa0665a1634a3c637a25d4f70227dead7e298d76a9eab7468eab9c2098e3970507545a31656f1a8f2155f444c569d3e3c995cf04e171f922f1a5eb4abb8fe0aa3d91c2dad28afc354faae1e63661115b76918fd371c05546f927454f312546ee4ae91067c82b6b09696384d31c760358b4a3b71645cf0e9733740a3531fd0273c33d5e74a1ad45ed384ec50fb3e7c63c09c8a6bb6fd6d0ef62b3339938918f78592994935233972b173318a4291b005fe0b67f3c19039fe210a1762de79baa8db4dfa6b6d3322c43a940b54c282284f658a9080ad4b713d1e3f9e1c63cc42f3dcee7265c092c7d004f020b34655ef5efcb18848944a5ded9d58e0069e9637befd026bccc505651b17ace6b1da7bb0d8b0ced0537a17a842a70741bad75c6388ab34f71a61629d006f8f6e8483d4c6fcb4542174b69b94fffd05c0935bdbf6c1dc3766893b7fe245a12238792beebfbbfb48cc90e3da20874bef6109d6081dfbf691efce5d093ea31a0ea714afce97c8ed8f3f389f555579e976e5b4957f2b9bc4bfb7dc41564ce106947e73dab38b2dbf8935b4770b804eed463a57ad653f79dae87b0025acd5044c1000e45e13e23838ec84bc00246edea02d5e5883dea30161cfb02059e18551a1bbd67587caf189508a479ddb46873d5bbbe87258435ebbea1ffa95d0d1e2dbc6b98703e0807117a19ad732c171d86afe033ade0d92d2e1824b0e31f77721c54e386a614f883b7758cb6e771624041d4517fe025c2ddbe8f060b15faf04f99e39ba9dcaec22e8d8e8ec82f320ca07618c8b45a9a76f980022aef26981f45e221f3f90e23b8a2cc1c224099ab12ddc5c2c7fb0d7c67ece086ae3815e76ba65f16a310f1fac4fcc27137c4a96f73bccfdb24b051b7433944881a3fdb117958c593f1babd0ffd071c50ab48807a4df2a1c45ff7a56d914f34072d0ddf55a670ab198389ebf1c2e7ac90ba612646d68d9a6358bde87479216876db9dc18a438b43934fea436d2739795f7451cc643";
        uint256 amount = 1e18;
        Cluster memory cluster = Cluster(12, 63_401_980_317, 61_355_463_060, true, 50_750_322_837_150_000_000);

        nodeDelegator2.registerSsvValidator(publicKey, operatorIds, sharesData, amount, cluster);

        (uint256 ndcEthAfter, uint256 eigenEthAfter) = nodeDelegator2.getAssetBalance(Addresses.WETH_TOKEN);
        assertEq(ndcEthAfter, ndcEthBefore, "WETH/ETH in NodeDelegator after");
        assertEq(eigenEthAfter, eigenEthBefore, "WETH/ETH in EigenLayer after");

        vm.stopPrank();
    }
}
