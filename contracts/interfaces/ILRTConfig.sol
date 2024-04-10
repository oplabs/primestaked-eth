// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

interface ILRTConfig {
    // Errors
    error ValueAlreadyInUse(); // 0x18e6d519
    error AssetAlreadySupported(); // 0xb1093e5b
    error AssetNotSupported(); // 0x981a2a2b
    error CallerNotLRTConfigAdmin(); // 0x164931f4
    error CallerNotLRTConfigManager(); // 0x210d9c66
    error CallerNotLRTConfigOperator(); // 0x5d0e4dee
    error CallerNotLRTConfigAllowedRole(string role); // 0x2cd56641
    error CannotUpdateStrategyAsItHasFundsNDCFunds(address ndc, uint256 amount); // 0x0c7652d9
    error CallerNotLRTDepositPool(); // 0x69b4678f

    // Events
    event SetToken(bytes32 key, address indexed tokenAddr);
    event SetContract(bytes32 key, address indexed contractAddr);
    event AddedNewSupportedAsset(address indexed asset, uint256 depositLimit);
    event RemovedSupportedAsset(address indexed asset);
    event AssetDepositLimitUpdate(address indexed asset, uint256 depositLimit);
    event AssetStrategyUpdate(address indexed asset, address indexed strategy);
    event SetPrimeETH(address indexed primeETH);

    // methods

    function primeETH() external view returns (address);

    function assetStrategy(address asset) external view returns (address);

    function isSupportedAsset(address asset) external view returns (bool);

    function getLSTToken(bytes32 tokenId) external view returns (address);

    function getContract(bytes32 contractId) external view returns (address);

    function getSupportedAssetList() external view returns (address[] memory);

    function depositLimitByAsset(address asset) external view returns (uint256);
}
