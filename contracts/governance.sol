pragma solidity ^0.6.2;

import {DSMath} from "./libraries/DSMath.sol";

contract GovernanceData is DSMath {
    address public admin;

    address public candyStore;
    address public randomness;

    uint public fee;
    uint public candyPrice;
    uint public profitShare;
    uint public lotteryDuration;

    address public lendingProxy;
    address public lotterySwap;
    address public candyStoreArbs;

    modifier isAdmin {
        require(admin == msg.sender, "not-a-admin");
        _;
    }

    function changeFee(uint _fee) external isAdmin {
        require(_fee < 5 * 10 ** 15, "governance/over-fee"); // 0.5% Max Fee.
        fee = _fee;
    }

    function changeCandyPrice(uint _price) external isAdmin {
        require(_price < 1 * WAD, "governance/over-price"); // 1$ Max Price.
        candyPrice = _price;
    }

    function changeDuration(uint _time) external isAdmin {
        require(_time <= 30 days, "governance/over-price"); // 30 days Max duration
        // require(_time >= 7 days, "governance/over-price"); // 7 days min duration
        lotteryDuration = _time;
    }

    function changelendingProxy(address _proxy) external isAdmin {
        require(_proxy != address(0), "governance/no-deposit-proxy-address");
        require(_proxy != lendingProxy, "governance/same-deposit-proxy-address");
        lendingProxy = _proxy;
    }

    function changeArbs(address _arbs) external isAdmin {
        require(_arbs != address(0), "governance/no-deposit-arbs-address");
        require(_arbs != candyStoreArbs, "governance/same-deposit-arbs-address");
        candyStoreArbs = _arbs;
    }

    function changeRandom(address _randomness) external isAdmin {
        require(_randomness != address(0), "governance/no-randomnesss-address");
        require(_randomness != randomness, "governance/same-randomnesss-address");
        randomness = _randomness;
    }

    function changeSwap(address _proxy) external isAdmin {
        require(_proxy != address(0), "governance/no-swap-proxy-address");
        require(_proxy != lotterySwap, "governance/same-swap-proxy-address");
        lotterySwap = _proxy;
    }

    function changeAdmin(address _admin) external isAdmin {
        require(_admin != address(0), "governance/no-admin-address");
        require(admin != _admin, "governance/same-admin");
        admin = _admin;
    }
}

contract Governance is GovernanceData {
    constructor (
        address _admin,
        uint _fee,
        uint _candyPrice,
        uint _duration,
        address _lendingProxy
    ) public {
        assert(_admin != address(0));
        assert(_fee != 0);
        assert(_candyPrice != 0);
        assert(_duration != 0);
        assert(_lendingProxy != address(0));
        admin = _admin;
        fee = _fee;
        candyPrice = _candyPrice;
        lotteryDuration = _duration;
        lendingProxy = _lendingProxy;
        
    }

    function init(address _candyStore, address _randomness, address _swap) public isAdmin {
        require(_randomness != address(0), "governance/no-randomnesss-address");
        require(_candyStore != address(0));
        require(_swap != address(0), "governance/no-swapLottery-address");
        randomness = _randomness;
        candyStore = _candyStore;
        lotterySwap = _swap;
    }
}