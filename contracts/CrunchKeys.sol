// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

contract CrunchKeys is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using AddressUpgradeable for address payable;

    address payable public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public builderFeePercent;

    mapping(address => mapping(address => uint256)) public keysBalance;
    mapping(address => uint256) public keysSupply;

    event SetProtocolFeeDestination(address indexed destination);
    event SetProtocolFeePercent(uint256 percent);
    event SetBuilderFeePercent(uint256 percent);

    event Trade(
        address indexed trader,
        address indexed builder,
        bool indexed isBuy,
        uint256 amount,
        uint256 price,
        uint256 protocolFee,
        uint256 builderFee,
        uint256 supply
    );

    function initialize(
        address payable _protocolFeeDestination,
        uint256 _protocolFeePercent,
        uint256 _builderFeePercent
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        protocolFeeDestination = _protocolFeeDestination;
        protocolFeePercent = _protocolFeePercent;
        builderFeePercent = _builderFeePercent;

        emit SetProtocolFeeDestination(_protocolFeeDestination);
        emit SetProtocolFeePercent(_protocolFeePercent);
        emit SetBuilderFeePercent(_builderFeePercent);
    }

    function setProtocolFeeDestination(
        address payable _feeDestination
    ) public onlyOwner {
        protocolFeeDestination = _feeDestination;
        emit SetProtocolFeeDestination(_feeDestination);
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
        emit SetProtocolFeePercent(_feePercent);
    }

    function setBuilderFeePercent(uint256 _feePercent) public onlyOwner {
        builderFeePercent = _feePercent;
        emit SetBuilderFeePercent(_feePercent);
    }

    function getPrice(
        uint256 supply,
        uint256 amount
    ) public pure returns (uint256 price) {
        uint256 startPrice = (1e15 + (supply) * 1e15);
        uint256 endPrice = (1e15 + (supply + amount - 1) * 1e15);
        price = ((startPrice + endPrice) / 2) * amount;
    }

    function getBuyPrice(
        address builder,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(keysSupply[builder], amount);
    }

    function getSellPrice(
        address builder,
        uint256 amount
    ) public view returns (uint256) {
        return getPrice(keysSupply[builder] - amount, amount);
    }

    function getBuyPriceAfterFee(
        address builder,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getBuyPrice(builder, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 builderFee = (price * builderFeePercent) / 1 ether;
        return price + protocolFee + builderFee;
    }

    function getSellPriceAfterFee(
        address builder,
        uint256 amount
    ) public view returns (uint256) {
        uint256 price = getSellPrice(builder, amount);
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 builderFee = (price * builderFeePercent) / 1 ether;
        return price - protocolFee - builderFee;
    }

    function executeTrade(
        address builder,
        uint256 amount,
        uint256 price,
        bool isBuy
    ) private nonReentrant {
        require(false, "Deprecated function");

        uint256 builderFee = (price * builderFeePercent) / 1 ether;
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;

        uint256 supply = keysSupply[builder];

        if (isBuy) {
            require(
                msg.value >= price + protocolFee + builderFee,
                "Insufficient payment"
            );
            keysBalance[builder][msg.sender] += amount;
            supply += amount;
            keysSupply[builder] = supply;
            protocolFeeDestination.sendValue(protocolFee);
            payable(builder).sendValue(builderFee);
            if (msg.value > price + protocolFee + builderFee) {
                uint256 refund = msg.value - price - protocolFee - builderFee;
                payable(msg.sender).sendValue(refund);
            }
        } else {
            require(
                keysBalance[builder][msg.sender] >= amount,
                "Insufficient keys"
            );
            keysBalance[builder][msg.sender] -= amount;
            supply -= amount;
            keysSupply[builder] = supply;
            uint256 netAmount = price - protocolFee - builderFee;
            payable(msg.sender).sendValue(netAmount);
            protocolFeeDestination.sendValue(protocolFee);
            payable(builder).sendValue(builderFee);
        }

        emit Trade(
            msg.sender,
            builder,
            isBuy,
            amount,
            price,
            protocolFee,
            builderFee,
            supply
        );
    }

    function buyKeys(address builder, uint256 amount) external payable {
        uint256 price = getBuyPrice(builder, amount);
        executeTrade(builder, amount, price, true);
    }

    function sellKeys(address builder, uint256 amount) external {
        uint256 price = getSellPrice(builder, amount);
        executeTrade(builder, amount, price, false);
    }
}
