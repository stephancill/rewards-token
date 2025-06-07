// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, ERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin-contracts-5.3.0/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin-contracts-5.3.0/access/Ownable.sol";

import {IRewardsTokenFactoryV1} from "./interfaces/IRewardsTokenFactoryV1.sol";

contract RewardsTokenV1 is ERC20Pausable, Ownable {
    error NoRewards();
    error NotDistributing();
    error NotEnoughRewards();
    error NotAuthorized();

    mapping(address account => uint256 lastClaimedDistributionId)
        public lastDistributionId;

    uint256 public immutable createdTimestamp;

    IERC20 public rewardToken;
    uint256 public rewardsPerDistributionPeriod;

    uint256 public currentDistributionId;

    bool public isDistributing;

    IRewardsTokenFactoryV1 public immutable rewardsTokenFactory;

    /**
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param _owner The owner of the token
     * @param _rewardToken The reward token
     * @param _rewardsPerDistributionPeriod The amount of rewards per distribution period
     * @param _rewardsTokenFactory The rewards token factory
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _rewardToken,
        uint256 _rewardsPerDistributionPeriod,
        IRewardsTokenFactoryV1 _rewardsTokenFactory
    ) ERC20(_name, _symbol) Ownable(_owner) {
        createdTimestamp = block.timestamp;
        rewardToken = IERC20(_rewardToken);
        rewardsPerDistributionPeriod = _rewardsPerDistributionPeriod;
        rewardsTokenFactory = _rewardsTokenFactory;
    }

    modifier onlyAuthorizedOrOwner() {
        if (
            msg.sender != rewardsTokenFactory.globalConfig().authority() &&
            msg.sender != owner()
        ) {
            revert NotAuthorized();
        }
        _;
    }

    /**
     * @notice Issues and
     * @param from The address of the sender
     * @param to The address of the recipient
     * @param amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        // Burn the user's balance if they haven't claimed their rewards yet
        // This should never happen if their rewards are distributed on time
        if (lastDistributionId[to] < currentDistributionId) {
            _burn(to, balanceOf(to));
        }

        if (from == owner()) {
            _mint(to, amount);
        }

        return super.transferFrom(from, to, amount);
    }

    /**
     * @notice Distributes the reward to a recipient
     * @param recipient The recipient of the rewards
     */
    function distributeReward(address recipient) public {
        if (!isDistributing) {
            revert NotDistributing();
        }

        uint256 reward = calculateRewards(recipient);

        if (reward == 0) {
            revert NoRewards();
        }

        _burn(recipient, reward);

        rewardToken.transferFrom(owner(), recipient, reward);
    }

    /**
     * @notice Starts the distribution of rewards
     */
    function startDistribution() public onlyAuthorizedOrOwner {
        if (rewardToken.balanceOf(owner()) < rewardsPerDistributionPeriod) {
            revert NotEnoughRewards();
        }

        // Transfer fees to authority
        uint256 fees = calculateFees();
        rewardToken.transferFrom(
            owner(),
            rewardsTokenFactory.globalConfig().authority(),
            fees
        );

        isDistributing = true;
        currentDistributionId++;
        _pause();
    }

    /**
     * @notice Stops the distribution of rewards
     */
    function stopDistribution() public onlyAuthorizedOrOwner {
        isDistributing = false;
        _unpause();
    }

    function calculateFees() public view returns (uint256) {
        return
            (rewardsPerDistributionPeriod *
                rewardsTokenFactory.globalConfig().authorityFeeBps()) / 10000;
    }

    /**
     * @notice Calculates the amount of rewards to distribute to a recipient in the current distribution period
     * @param recipient The recipient of the rewards
     * @return The amount of rewards to distribute
     */
    function calculateRewards(address recipient) public view returns (uint256) {
        // Rewards are calculated based on percentage of the total supply
        // that has been distributed

        uint256 totalSupply = totalSupply();
        uint256 distributedSupply = balanceOf(recipient);
        uint256 fees = calculateFees();

        uint256 rewards = (distributedSupply *
            (rewardsPerDistributionPeriod - fees)) / totalSupply;

        return rewards;
    }
}
