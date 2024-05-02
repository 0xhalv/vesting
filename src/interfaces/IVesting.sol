// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IVesting {
    /// @dev emitted on successful distribution
    event Distributed(uint256 indexed epoch, address[] recipients, uint256[] values);

    /**
     * @notice  distribute unlocked tokens for current epoch
     * @param   _recipients  array of addresses of token recipients
     * @param   _values  array of tokens to distribute to respective address
     */
    function distribute(
        address[] calldata _recipients,
        uint256[] calldata _values
    ) external;

    /*
     * @notice  distribute unlocked tokens for given epoch
     * @param   _epoch  epoch id
     * @param   _recipients  array of addresses of token recipients
     * @param   _values  array of tokens to distribute to respective address
     */
    function distributeForEpoch(
        uint256 _epoch,
        address[] calldata _recipients,
        uint256[] calldata _values
    ) external;

    /**
     * @notice  When vesting finishes, admin can withdraw the rest of tokens
     */
    function withdrawAll() external;

    /**
     * @notice  returns the epoch id for given timestamp
     * @param   _ts  timestamp
     * @return  uint256  epoch id
     */
    function timestampToEpoch(uint256 _ts) external view returns (uint256);

    /**
     * @notice  returns max amount of tokens claimable in given epoch
     * @param   _epoch  epoch id
     * @return  uint256  amount of tokens
     */
    function claimableInEpoch(uint256 _epoch) external view returns (uint256);
}
