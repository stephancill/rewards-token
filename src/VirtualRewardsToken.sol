// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, ERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin-contracts-5.3.0/access/Ownable.sol";

import {IVirtualRewardsTokenFactory} from "./interfaces/IVirtualRewardsTokenFactory.sol";

contract VirtualRewardsToken is ERC20, Ownable {
    string public constant VERSION = "1.0.0";

    error NotDistributing();
    error AlreadyDistributing();
    error NotEnoughRewards();
    error NotAuthorized();
    error Paused();

    mapping(address account => uint256 lastClaimedDistributionId) public lastDistributionId;

    uint256 public immutable createdTimestamp;

    IERC20 public rewardToken;
    uint256 public rewardsPerDistributionPeriod;

    uint256 public currentDistributionId;
    bool public isDistributing;
    bool public isPaused;

    IVirtualRewardsTokenFactory public immutable virtualRewardsTokenFactory;

    /**
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param _owner The owner of the token
     * @param _rewardToken The reward token
     * @param _rewardsPerDistributionPeriod The amount of rewards per distribution period
     * @param _virtualRewardsTokenFactory The virtual rewards token factory
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _rewardToken,
        uint256 _rewardsPerDistributionPeriod,
        IVirtualRewardsTokenFactory _virtualRewardsTokenFactory
    ) ERC20(_name, _symbol) Ownable(_owner) {
        createdTimestamp = block.timestamp;
        rewardToken = IERC20(_rewardToken);
        rewardsPerDistributionPeriod = _rewardsPerDistributionPeriod;
        virtualRewardsTokenFactory = _virtualRewardsTokenFactory;
    }

    modifier onlyAuthorizedOrOwner() {
        if (msg.sender != virtualRewardsTokenFactory.globalConfig().authority() && msg.sender != owner()) {
            revert NotAuthorized();
        }
        _;
    }

    function beforeTokenTransfer(address from, address to, uint256 amount) internal {
        if (isPaused) {
            revert Paused();
        }

        // Burn the user's balance if they haven't claimed their rewards yet
        // This should never happen if their rewards are distributed on time
        if (lastDistributionId[to] < currentDistributionId) {
            _burn(to, balanceOf(to));
            lastDistributionId[to] = currentDistributionId;
        }

        if (from == owner()) {
            _mint(from, amount);
        }
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        beforeTokenTransfer(from, to, amount);
        return super.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        beforeTokenTransfer(msg.sender, to, amount);
        return super.transfer(to, amount);
    }

    /**
     * @notice Distributes the reward to a recipient
     * @param recipient The recipient of the rewards
     */
    function distributeReward(address recipient) public {
        if (!isDistributing) {
            revert NotDistributing();
        }

        if (lastDistributionId[recipient] < currentDistributionId) {
            _burn(recipient, balanceOf(recipient));
            return;
        }

        uint256 reward = calculateReward(recipient);

        if (reward == 0) return;

        _burn(recipient, balanceOf(recipient));

        rewardToken.transferFrom(owner(), recipient, reward);
    }

    /**
     * @notice Starts the distribution of rewards
     */
    function startDistribution() public onlyAuthorizedOrOwner {
        if (isDistributing) {
            revert AlreadyDistributing();
        }

        if (rewardToken.balanceOf(owner()) < rewardsPerDistributionPeriod) {
            revert NotEnoughRewards();
        }

        // Transfer fees to authority
        uint256 fees = calculateFees();
        rewardToken.transferFrom(owner(), virtualRewardsTokenFactory.globalConfig().authority(), fees);

        isDistributing = true;
        isPaused = true;
    }

    /**
     * @notice Stops the distribution of rewards
     */
    function stopDistribution() public onlyAuthorizedOrOwner {
        if (!isDistributing) {
            revert NotDistributing();
        }

        currentDistributionId++;
        isDistributing = false;
        isPaused = false;
    }

    function calculateFees() public view returns (uint256) {
        return (rewardsPerDistributionPeriod * virtualRewardsTokenFactory.globalConfig().authorityFeeBps()) / 10000;
    }

    /**
     * @notice Calculates the amount of reward tokens to distribute to a recipient in the current distribution period
     * @param recipient The recipient of the rewards
     * @return The amount of reward tokens to distribute
     */
    function calculateReward(address recipient) public view returns (uint256) {
        uint256 totalSupply = totalSupply();
        uint256 distributedSupply = balanceOf(recipient);
        uint256 fees = calculateFees();

        uint256 rewards = (distributedSupply * (rewardsPerDistributionPeriod - fees)) / totalSupply;

        return rewards;
    }
}
