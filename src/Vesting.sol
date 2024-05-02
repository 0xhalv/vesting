// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IVesting} from "./interfaces/IVesting.sol";

/**
 * @author  0xhalv
 * @title   Vesting contract
 * @notice  Contract that distributes ERC20 tokens on a monthly basis
 */
contract Vesting is
    IVesting,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /// @dev epoch is 1 month
    uint256 private constant EPOCH_DURATION = 30 days;
    /// @dev for convenience when using fixed point math
    uint256 private constant ONE_PERCENT = FixedPointMathLib.WAD / 100;

    /// @dev token to lock and distribute
    IERC20 private token;
    /// @dev start time of the first epoch
    uint96 private startTime;
    /// @dev max amount of tokens to claim per epoch (epoch = month)
    uint256 private maxTokensInEpoch;
    /// @dev epoch => claimed, amount of tokens claimed in respective epoch
    mapping(uint256 => uint256) private claimedInEpoch;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice  Initializes the proxy contract
     * @param   _token  address of the locked token
     * @param   _owner  owner the contract
     * @param   _maxTokensInEpoch  max amount of tokens to unlock in 1 month
     * @param   _startTime  timestamp of the first epoch
     */
    function initialize(
        address _token,
        address _owner,
        uint256 _maxTokensInEpoch,
        uint96 _startTime
    ) external initializer {
        require(_token != address(0), "zero address");
        require(_owner != address(0), "zero address");
        require(_startTime >= block.timestamp, "invalid start time");

        __Ownable_init(_owner);
        token = IERC20(_token);
        maxTokensInEpoch = _maxTokensInEpoch;
        startTime = _startTime;
    }

    /// @inheritdoc IVesting
    function distribute(
        address[] calldata _recipients,
        uint256[] calldata _values
    ) external onlyOwner {
        uint256 epoch = timestampToEpoch(block.timestamp);
        distributeForEpoch(epoch, _recipients, _values);
    }

    /// @inheritdoc IVesting
    function distributeForEpoch(
        uint256 _epoch,
        address[] calldata _recipients,
        uint256[] calldata _values
    ) public onlyOwner nonReentrant {
        uint256 currentEpoch = timestampToEpoch(block.timestamp);
        require(_epoch <= currentEpoch, "epoch in future");
        require(_recipients.length == _values.length, "array length mismatch");
        uint256 claimable = claimableInEpoch(_epoch);
        uint256 claimed = claimedInEpoch[_epoch];

        for(uint256 i = 0; i < _recipients.length; ++i) {
            uint256 amount = _values[i];
            address recipient = _recipients[i];
            claimed += amount;
            token.safeTransfer(recipient, amount);
        }
        require(claimed <= claimable, "claiming too much");
        claimedInEpoch[_epoch] = claimed;
        emit Distributed(_epoch, _recipients, _values);
    }

    /// @inheritdoc IVesting
    function withdrawAll() external onlyOwner {
        uint256 epoch = timestampToEpoch(block.timestamp);
        uint256 percent = percentInEpoch(epoch);
        require(percent <= ONE_PERCENT, "vesting didnt finish");
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.safeTransfer(msg.sender, balance);
        }
    }

    /// @inheritdoc IVesting
    function timestampToEpoch(uint256 _ts) public view returns (uint256) {
        require(_ts >= startTime, "invalid time");
        return (_ts - startTime) / EPOCH_DURATION + 1;
    }

    /// @inheritdoc IVesting
    function claimableInEpoch(uint256 _epoch) public view returns (uint256) {
        uint256 percent = percentInEpoch(_epoch);
        require(percent > ONE_PERCENT, "vesting finished");
        return FixedPointMathLib.mulWadDown(maxTokensInEpoch, percent);
    }

    /**
     * @notice  returns the percentage of max claimable tokens for given epoch
     * @notice  year 1 - 10%
     * @notice  year 2 - 25%
     * @notice  year 3 - 50%
     * @notice  year 4 - 100%
     * @notice  year 5-8 - 50%
     * @notice  year 9-12 - 25% etc... 
     * @dev     formula for years 2-4:
     * @dev     period = 4 - year
     * @dev     percent = 100 * (0.5^period)
     * @dev     ********************
     * @dev     formula for years 5+:
     * @dev     period = ((year - 4) / 4)
     * @dev     percent = 100 * (0.5^period)
     * @param   _epoch  epoch id
     * @return  uint256  percentage
     */
    function percentInEpoch(uint256 _epoch) internal pure returns (uint256) {
        // 10% in the first year
        if (_epoch <= 12) {
            return 10 * ONE_PERCENT;
        }
        uint256 year = FixedPointMathLib.unsafeDivUp(_epoch, 12);
        uint256 period;
        if (_epoch <= 48) {
            period = 4 - year;
        } else {
            period = FixedPointMathLib.unsafeDivUp(year - 4, 4); // period for years 5+
        }
        uint256 multiplier = FixedPointMathLib.rpow(FixedPointMathLib.WAD / 2, period, FixedPointMathLib.WAD);
        return FixedPointMathLib.mulWadDown(100 * ONE_PERCENT, multiplier);
    }
}