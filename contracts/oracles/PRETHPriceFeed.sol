// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IRSETHOracle {
    function prETHPrice() external view returns (uint256);
}

contract RSETHPriceFeed is AggregatorV3Interface {
    /// @notice Price feed for (ETH / USD) pair
    AggregatorV3Interface public immutable ETH_TO_USD;

    /// @notice prETH oracle contract
    IRSETHOracle public immutable RS_ETH_ORACLE;

    string public description;

    /// @param ethToUSDAggregatorAddress the address of ETH / USD feed
    /// @param prETHOracle the address of prETHOracle contract
    /// @param description_ priceFeed description (PrimeStakedETH / USD)
    constructor(address ethToUSDAggregatorAddress, address prETHOracle, string memory description_) {
        ETH_TO_USD = AggregatorV3Interface(ethToUSDAggregatorAddress);
        RS_ETH_ORACLE = IRSETHOracle(prETHOracle);

        description = description_;
    }

    function decimals() external view returns (uint8) {
        return ETH_TO_USD.decimals();
    }

    function version() external view returns (uint256) {
        return ETH_TO_USD.version();
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = ETH_TO_USD.getRoundData(_roundId);

        answer = int256(RS_ETH_ORACLE.prETHPrice()) * answer / 1e18;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = ETH_TO_USD.latestRoundData();
        answer = int256(RS_ETH_ORACLE.prETHPrice()) * answer / 1e18;
    }
}
