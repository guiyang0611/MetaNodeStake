// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract MetaNodeStake is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    uint256 public constant ETH_PID = 0;

    struct Pool {
        address stToken; // 质押代币合约地址
        uint256 poolWeights; // 质押池权重
        uint256 lastRewardBlock; // 上次分配奖励的区块高度
        uint256 accMetaNodePerST; // 每股累计奖励代币
        uint256 stAmount; // 质押代币总量
        uint256 minDepositAmount; // 最小质押数量
        uint256 unStakeLockBolcks; // 质押锁定期，单位：区块数
    }

    struct UnStakeRequest {
        uint256 amount; // 待提取数量
        uint256 unlockBlocks; // 提取开始时间
    }

    struct UserInfo {
        uint256 amount; // 用户质押数量
        uint256 finishedMetaNode; // 用户已领取奖励
        uint256 pendingMetaNode; // 用户待领取奖励
        UnStakeRequest[] unStakeRequests; // 用户的提取请求
    }

    uint256 public unlockBlocks; // 质押开始区块高度
    uint256 public endBlock; // 质押结束区块高度
    uint256 public metaNodePreBlock; // 奖励代币每区块数量
    bool public claimPaused; // 提取奖励是否暂停
    bool public unStakePaused; // 提取质押是否暂停

    IERC20 public MetaNode; // 奖励代币合约地址
    uint256 public totalPoolWeight; // 质押池总权重
    Pool[] public pools; // 质押池列表

    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // 用户信息映射，池ID => 用户地址 => 用户信息

    event SetMetaNode(IERC20 indexed MetaNode);

    event PauseWithdraw();

    event UnpauseWithdraw();

    event PauseClaim();

    event UnpauseClaim();

    event SetunlockBlocks(uint256 indexed unlockBlocks);

    event SetEndBlock(uint256 indexed endBlock);

    event SetMetaNodePerBlock(uint256 indexed MetaNodePerBlock);

    event AddPool(
        address indexed stTokenAddress,
        uint256 indexed poolWeight,
        uint256 indexed lastRewardBlock,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks
    );

    event UpdatePoolInfo(
        uint256 indexed poolId,
        uint256 indexed minDepositAmount,
        uint256 indexed unstakeLockedBlocks
    );

    event SetPoolWeight(
        uint256 indexed poolId,
        uint256 indexed poolWeight,
        uint256 totalPoolWeight
    );

    event UpdatePool(
        uint256 indexed poolId,
        uint256 indexed lastRewardBlock,
        uint256 totalMetaNode
    );

    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);

    event RequestUnstake(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 indexed blockNumber
    );

    event Claim(
        address indexed user,
        uint256 indexed poolId,
        uint256 MetaNodeReward
    );

    modifier checkPid(uint256 _pid) {
        require(_pid < pools.length, "MetaNodeStake: Pool does not exist");
        _;
    }

    modifier whenNotClaimPaused() {
        require(!claimPaused, "MetaNodeStake: Claim paused");
        _;
    }

    modifier whenNotUnStakePaused() {
        require(!unStakePaused, "MetaNodeStake: Unstake paused");
        _;
    }

    function initialize(
        IERC20 _metaNode,
        uint256 _unlockBlocks,
        uint256 _endBlock,
        uint256 _metaNodePreBlock
    ) public initializer {
        require(
            address(_metaNode) != address(0),
            "MetaNodeStake: Invalid MetaNode address"
        );
        require(
            _unlockBlocks < _endBlock,
            "MetaNodeStake: unlockBlocks must be less than endBlock"
        );
        require(_metaNodePreBlock > 0, "MetaNodeStake: Invalid reward");
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        setMetaNode(_metaNode);
        unlockBlocks = _unlockBlocks;
        endBlock = _endBlock;
        metaNodePreBlock = _metaNodePreBlock;
    }

    /**
     * * @dev 升级权限控制
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADE_ROLE) {}

    function setMetaNode(IERC20 _metaNode) public onlyRole(ADMIN_ROLE) {
        MetaNode = _metaNode;

        emit SetMetaNode(MetaNode);
    }

    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!unStakePaused, "MetaNodeStake: Unstake already paused");
        unStakePaused = true;

        emit PauseWithdraw();
    }

    function unPauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(unStakePaused, "MetaNodeStake: Unstake not paused");
        unStakePaused = false;

        emit UnpauseWithdraw();
    }

    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "MetaNodeStake: Claim already paused");
        claimPaused = true;

        emit PauseClaim();
    }

    function unPauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "MetaNodeStake: Claim not paused");
        claimPaused = false;

        emit UnpauseClaim();
    }

    function setunlockBlocks(
        uint256 _unlockBlocks
    ) public onlyRole(ADMIN_ROLE) {
        require(
            _unlockBlocks <= endBlock,
            "MetaNodeStake: unlockBlocks must be less than or equal to endBlock"
        );
        unlockBlocks = _unlockBlocks;

        emit SetunlockBlocks(_unlockBlocks);
    }

    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(
            _endBlock >= unlockBlocks,
            "MetaNodeStake: endBlock must be greater than or equal to unlockBlocks"
        );
        endBlock = _endBlock;

        emit SetEndBlock(_endBlock);
    }

    function setMetaNodePreBlock(
        uint256 _metaNodePreBlock
    ) public onlyRole(ADMIN_ROLE) {
        require(_metaNodePreBlock > 0, "MetaNodeStake: Invalid reward");
        metaNodePreBlock = _metaNodePreBlock;

        emit SetMetaNodePerBlock(_metaNodePreBlock);
    }

    function addPool(
        address _stToken,
        uint256 _poolWeights,
        uint256 _minDepositAmount,
        uint256 _unStakeLockBolcks
    ) public onlyRole(ADMIN_ROLE) {
        if (pools.length > 0) {
            require(
                _stToken != address(0x0),
                "MetaNodeStake: Invalid stToken address"
            );
        } else {
            require(
                _stToken == address(0x0),
                "MetaNodeStake: The first pool must be ETH pool"
            );
        }

        require(_poolWeights > 0, "MetaNodeStake: Invalid pool weights");
        require(_minDepositAmount > 0, "MetaNodeStake: Invalid min deposit");
        require(
            _unStakeLockBolcks > 0,
            "MetaNodeStake: Invalid unstake lock blocks"
        );
        require(block.number < endBlock, "MetaNodeStake: Pool expired");
        uint256 _lastRewardBlock = block.number > unlockBlocks
            ? block.number
            : unlockBlocks;
        totalPoolWeight += _poolWeights;
        pools.push(
            Pool({
                stToken: _stToken,
                poolWeights: _poolWeights,
                lastRewardBlock: _lastRewardBlock,
                accMetaNodePerST: 0,
                stAmount: 0,
                minDepositAmount: _minDepositAmount,
                unStakeLockBolcks: _unStakeLockBolcks
            })
        );

        emit AddPool(
            _stToken,
            _poolWeights,
            _lastRewardBlock,
            _minDepositAmount,
            _unStakeLockBolcks
        );
    }

    function updatePool(
        uint256 _pid,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) public checkPid(_pid) onlyRole(ADMIN_ROLE) {
        require(_minDepositAmount > 0, "MetaNodeStake: Invalid pool weights");
        require(_unstakeLockedBlocks > 0, "MetaNodeStake: Invalid min deposit");
        pools[_pid].unStakeLockBolcks = _unstakeLockedBlocks;
        pools[_pid].minDepositAmount = _minDepositAmount;

        emit UpdatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks);
    }

    function setPoolWeight(
        uint256 _pid,
        uint256 _poolWeight
    ) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        require(_poolWeight > 0, "invalid pool weight");

        totalPoolWeight =
            totalPoolWeight -
            pools[_pid].poolWeights +
            _poolWeight;
        pools[_pid].poolWeights = _poolWeight;

        emit SetPoolWeight(_pid, _poolWeight, totalPoolWeight);
    }

    function poolLength() external view returns (uint256) {
        return pools.length;
    }

    /**
     * @dev 计算从 _from 到 _to 区块的奖励乘数
     */
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256 multiplier) {
        require(_from <= _to, "invalid block");
        if (_from < unlockBlocks) {
            _from = unlockBlocks;
        }
        if (_to > endBlock) {
            _to = endBlock;
        }
        require(_from <= _to, "end block must be greater than start block");
        bool success;
        (success, multiplier) = (_to - _from).tryMul(metaNodePreBlock);
        require(success, "multiplier overflow");
    }

    function pendingMetaNode(
        uint256 _pid,
        address _user
    ) external view checkPid(_pid) returns (uint256) {
        return pendingMetaNodeByBlockNumber(_pid, _user, block.number);
    }

    /**
     * @dev 获取用户待领取的 MetaNode 奖励
     */
    function pendingMetaNodeByBlockNumber(
        uint256 _pid,
        address _user,
        uint256 _blockNumber
    ) public view checkPid(_pid) returns (uint256) {
        Pool storage _pool = pools[_pid];
        UserInfo storage user_ = userInfo[_pid][_user];
        uint256 accMetaNodePerST = _pool.accMetaNodePerST;
        uint256 stSupply = _pool.stAmount;

        if (_blockNumber > _pool.lastRewardBlock && stSupply != 0) {
            uint256 multiplier = getMultiplier(
                _pool.lastRewardBlock,
                _blockNumber
            );
            uint256 MetaNodeForPool = (multiplier * _pool.poolWeights) /
                totalPoolWeight;
            accMetaNodePerST =
                accMetaNodePerST +
                (MetaNodeForPool * (1 ether)) /
                stSupply;
        }

        return
            (user_.amount * accMetaNodePerST) /
            (1 ether) -
            user_.finishedMetaNode +
            user_.pendingMetaNode;
    }

    /**
     * @dev 获取用户质押的代币余额
     */
    function stakingBalance(
        uint256 _pid,
        address _user
    ) external view checkPid(_pid) returns (uint256) {
        UserInfo storage user_ = userInfo[uint256(_pid)][_user];
        return user_.amount;
    }

    /**
     * @dev 获取用户可提取的质押数量和待提取数量
     */
    function withdrawAmount(
        uint256 _pid,
        address user
    )
        public
        view
        checkPid(_pid)
        returns (uint256 requestAmount, uint256 pendingWithdrawAmount)
    {
        UserInfo storage _user = userInfo[uint256(_pid)][user];
        requestAmount = _user.amount;
        for (uint256 i = 0; i < _user.unStakeRequests.length; i++) {
            UnStakeRequest storage request = _user.unStakeRequests[i];
            if (block.number >= _user.unStakeRequests[i].unlockBlocks) {
                pendingWithdrawAmount += request.amount;
            }
            requestAmount += _user.unStakeRequests[i].amount;
        }
    }

    /**
     * @dev 更新质押池的奖励变量
     */
    function updatePool(uint256 _pid) public checkPid(_pid) {
        Pool storage pool = pools[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        // 计算从 lastRewardBlock 到 block.number 区间的 MetaNode 奖励
        (bool success1, uint256 totalMetaNode) = getMultiplier(
            pool.lastRewardBlock,
            block.number
        ).tryMul(pool.poolWeights / totalPoolWeight);
        require(success1, "multiplier overflow");

        // 计算每股奖励
        (success1, totalMetaNode) = totalMetaNode.tryDiv(totalPoolWeight);
        require(success1, "multiplier overflow");
        // 更新每股累计奖励
        uint256 stSupply = pool.stAmount;
        if (stSupply > 0) {
            // 计算每股奖励
            (bool success2, uint256 totalMetaNode_) = totalMetaNode.tryMul(
                1 ether
            );
            require(success2, "overflow");
            // 计算每股累计奖励
            (success2, totalMetaNode_) = totalMetaNode_.tryDiv(stSupply);
            require(success2, "overflow");
            // 更新每股累计奖励
            (bool success3, uint256 accMetaNodePerST) = pool
                .accMetaNodePerST
                .tryAdd(totalMetaNode_);
            require(success3, "overflow");
            pool.accMetaNodePerST = accMetaNodePerST;
        }
        pool.lastRewardBlock = block.number;

        emit UpdatePool(_pid, pool.lastRewardBlock, totalMetaNode);
    }

    /**
     * @dev 更新所有质押池的奖励变量
     */
    function massUpdatePools() public {
        uint256 length = pools.length;
        for (uint256 pid = 0; pid < length; pid++) {
            updatePool(pid);
        }
    }

    /**
     * @dev 用户质押代币
     */
    function depositETH() public payable whenNotPaused {
        Pool storage pool_ = pools[ETH_PID];
        require(pool_.stToken == address(0x0), "invalid staking token address");

        uint256 _amount = msg.value;
        require(
            _amount >= pool_.minDepositAmount,
            "deposit amount is too small"
        );

        _deposit(ETH_PID, _amount);
    }

    /**
     * @dev 用户质押代币
     */
    function deposit(
        uint256 _pid,
        uint256 _amount
    ) public whenNotPaused checkPid(_pid) {
        require(_pid != 0, "deposit not support ETH staking");
        Pool storage pool_ = pools[_pid];
        require(
            _amount > pool_.minDepositAmount,
            "deposit amount is too small"
        );

        if (_amount > 0) {
            IERC20(pool_.stToken).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }

        _deposit(_pid, _amount);
    }

    /**
     * @dev 用户取消质押代币
     */
    function unstake(
        uint256 _pid,
        uint256 _amount
    ) public whenNotPaused checkPid(_pid) whenNotUnStakePaused {
        Pool storage pool_ = pools[_pid];
        UserInfo storage user_ = userInfo[_pid][msg.sender];

        require(user_.amount >= _amount, "Not enough staking token balance");

        updatePool(_pid);

        uint256 pendingMetaNode_ = (user_.amount * pool_.accMetaNodePerST) /
            (1 ether) -
            user_.finishedMetaNode;

        if (pendingMetaNode_ > 0) {
            user_.pendingMetaNode = user_.pendingMetaNode + pendingMetaNode_;
        }

        if (_amount > 0) {
            user_.amount = user_.amount - _amount;
            user_.unStakeRequests.push(
                UnStakeRequest({
                    amount: _amount,
                    unlockBlocks: block.number + pool_.unStakeLockBolcks
                })
            );
        }

        pool_.stAmount = pool_.stAmount - _amount;
        user_.finishedMetaNode =
            (user_.amount * pool_.accMetaNodePerST) /
            (1 ether);

        emit RequestUnstake(msg.sender, _pid, _amount);
    }

    /**
     * @dev 提取代币
     */
    function withdraw(
        uint256 _pid
    ) public whenNotPaused checkPid(_pid) whenNotUnStakePaused {
        Pool storage pool_ = pools[_pid];
        UserInfo storage user_ = userInfo[_pid][msg.sender];

        uint256 pendingWithdraw_;
        uint256 popNum_;
        for (uint256 i = 0; i < user_.unStakeRequests.length; i++) {
            if (user_.unStakeRequests[i].unlockBlocks > block.number) {
                break;
            }
            pendingWithdraw_ =
                pendingWithdraw_ +
                user_.unStakeRequests[i].amount;
            popNum_++;
        }

        for (uint256 i = 0; i < user_.unStakeRequests.length - popNum_; i++) {
            user_.unStakeRequests[i] = user_.unStakeRequests[i + popNum_];
        }

        for (uint256 i = 0; i < popNum_; i++) {
            user_.unStakeRequests.pop();
        }

        if (pendingWithdraw_ > 0) {
            if (pool_.stToken == address(0x0)) {
                _safeETHTransfer(msg.sender, pendingWithdraw_);
            } else {
                IERC20(pool_.stToken).safeTransfer(
                    msg.sender,
                    pendingWithdraw_
                );
            }
        }

        emit Withdraw(msg.sender, _pid, pendingWithdraw_, block.number);
    }

    function claim(
        uint256 _pid
    ) public whenNotPaused checkPid(_pid) whenNotClaimPaused {
        Pool storage pool_ = pools[_pid];
        UserInfo storage user_ = userInfo[_pid][msg.sender];

        updatePool(_pid);

        uint256 pendingMetaNode_ = (user_.amount * pool_.accMetaNodePerST) /
            (1 ether) -
            user_.finishedMetaNode +
            user_.pendingMetaNode;

        if (pendingMetaNode_ > 0) {
            user_.pendingMetaNode = 0;
            _safeMetaNodeTransfer(msg.sender, pendingMetaNode_);
        }

        user_.finishedMetaNode =
            (user_.amount * pool_.accMetaNodePerST) /
            (1 ether);

        emit Claim(msg.sender, _pid, pendingMetaNode_);
    }

    function _deposit(uint256 _pid, uint256 _amount) internal {
        Pool storage pool_ = pools[_pid];
        UserInfo storage user_ = userInfo[_pid][msg.sender];

        updatePool(_pid);

        if (user_.amount > 0) {
            // uint256 accST = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
            (bool success1, uint256 accST) = user_.amount.tryMul(
                pool_.accMetaNodePerST
            );
            require(success1, "user stAmount mul accMetaNodePerST overflow");
            (success1, accST) = accST.tryDiv(1 ether);
            require(success1, "accST div 1 ether overflow");

            (bool success2, uint256 pendingMetaNode_) = accST.trySub(
                user_.finishedMetaNode
            );
            require(success2, "accST sub finishedMetaNode overflow");

            if (pendingMetaNode_ > 0) {
                (bool success3, uint256 _pendingMetaNode) = user_
                    .pendingMetaNode
                    .tryAdd(pendingMetaNode_);
                require(success3, "user pendingMetaNode overflow");
                user_.pendingMetaNode = _pendingMetaNode;
            }
        }

        if (_amount > 0) {
            (bool success4, uint256 stAmount) = user_.amount.tryAdd(_amount);
            require(success4, "user stAmount overflow");
            user_.amount = stAmount;
        }

        (bool success5, uint256 stTokenAmount) = pool_.stAmount.tryAdd(_amount);
        require(success5, "pool stTokenAmount overflow");
        pool_.stAmount = stTokenAmount;

        // user_.finishedMetaNode = user_.stAmount.mulDiv(pool_.accMetaNodePerST, 1 ether);
        (bool success6, uint256 finishedMetaNode) = user_.amount.tryMul(
            pool_.accMetaNodePerST
        );
        require(success6, "user stAmount mul accMetaNodePerST overflow");

        (success6, finishedMetaNode) = finishedMetaNode.tryDiv(1 ether);
        require(success6, "finishedMetaNode div 1 ether overflow");

        user_.finishedMetaNode = finishedMetaNode;

        emit Deposit(msg.sender, _pid, _amount);
    }

    /**
     * @dev 安全转移 MetaNode 代币
     */
    function _safeMetaNodeTransfer(address _to, uint256 _amount) internal {
        uint256 MetaNodeBal = MetaNode.balanceOf(address(this));

        if (_amount > MetaNodeBal) {
            MetaNode.transfer(_to, MetaNodeBal);
        } else {
            MetaNode.transfer(_to, _amount);
        }
    }

    /**
     * @dev 安全转移 ETH
     */
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = address(_to).call{value: _amount}(
            ""
        );

        require(success, "ETH transfer call failed");
        if (data.length > 0) {
            require(
                abi.decode(data, (bool)),
                "ETH transfer operation did not succeed"
            );
        }
    }
}
