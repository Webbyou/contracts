pragma solidity ^0.6.0;

import {DSMath} from "../libraries/DSMath.sol";

import {TokenInterface} from "../interfaces/token.sol";
import {CTokenInterface, CETHInterface, ComptrollerInterface} from "../interfaces/compound.sol";
import {AaveInterface} from "../interfaces/aave.sol";
import {Mapping} from "../interfaces/mapping.sol";

contract Helpers is DSMath {
    /**
     * @dev Return ethereum address
     */
    function getAddressETH() internal pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // ETH Address
    }

    /**
     * @dev Return Mapping Addresses
     */
    function getMappingAddr() internal pure returns (address) {
        return 0xe81F70Cc7C0D46e12d70efc60607F16bbD617E88; // Mapping Address
    }
}


contract CompoundHelpers is Helpers {
    /**
     * @dev Return Compound Comptroller Address
     */
    function getComptrollerAddress() internal pure returns (address) {
        // return 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B; // mainnet
        return 0x1f5D7F3CaAC149fE41b8bd62A3673FE6eC0AB73b; //kovan
    }

    /**
     * @dev enter compound market
     */
    function enterMarket(address cToken) internal {
        ComptrollerInterface troller = ComptrollerInterface(getComptrollerAddress());
        address[] memory markets = troller.getAssetsIn(address(this));
        bool isEntered = false;
        for (uint i = 0; i < markets.length; i++) {
            if (markets[i] == cToken) {
                isEntered = true;
            }
        }
        if (!isEntered) {
            address[] memory toEnter = new address[](1);
            toEnter[0] = cToken;
            troller.enterMarkets(toEnter);
        }
    }
}


contract CompoundResolver is CompoundHelpers {
    event LogDepositCompound(address indexed token, address cToken, uint256 tokenAmt);
    event LogWithdrawCompound(address indexed token, address cToken, uint256 tokenAmt);

    /**
     * @dev Deposit ETH/ERC20_Token.
     * @param token token address to deposit.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to deposit.
    */
    function compoundDeposit(address token, uint amt) internal returns (uint _amt) {
        _amt = amt;
        address cToken = Mapping(getMappingAddr()).cTokenMapping(token);
        enterMarket(cToken);
        if (token == getAddressETH()) {
            require(_amt == msg.value, "not-enought-eth");
            CETHInterface(cToken).mint.value(_amt)();
        } else {
            TokenInterface tokenContract = TokenInterface(token);
            tokenContract.approve(cToken, _amt);
            require(CTokenInterface(cToken).mint(_amt) == 0, "mint-failed");
        }

        emit LogDepositCompound(token, cToken, _amt);
    }

    /**
     * @dev Withdraw ETH/ERC20_Token.
     * @param token token address to withdraw.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt token amount to withdraw.
    */
    function compoundWithdraw(address token, uint amt) internal returns (uint _amt) {
        _amt = amt;
        address cToken = Mapping(getMappingAddr()).cTokenMapping(token);
        CTokenInterface cTokenContract = CTokenInterface(cToken);
        if (_amt == uint(-1)) {
            TokenInterface tokenContract = TokenInterface(token);
            uint initialBal = token == getAddressETH() ? address(this).balance : tokenContract.balanceOf(address(this));
            require(cTokenContract.redeem(cTokenContract.balanceOf(address(this))) == 0, "full-withdraw-failed");
            uint finalBal = token == getAddressETH() ? address(this).balance : tokenContract.balanceOf(address(this));
            _amt = finalBal - initialBal;
        } else {
            require(cTokenContract.redeemUnderlying(_amt) == 0, "withdraw-failed");
        }

        emit LogWithdrawCompound(token, cToken, _amt);
    }
}

contract AaveHelpers is CompoundResolver {
    /**
     * @dev get Aave Address
    */
    function getAaveAddress() internal pure returns (address) {
        // return 0x398eC7346DcD622eDc5ae82352F02bE94C62d119; //mainnet
        return 0x580D4Fdc4BF8f9b5ae2fb9225D584fED4AD5375c;
    }

    /**
     * @dev get Aave Address
    */
    function getAaveProviderAddress() internal pure returns (address) {
        // return 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8; //mainnet
        return 0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5; //kovan
    }

    function getWithdrawBalance(address token) internal view returns (uint bal) {
        (bal, , , , , , , , , ) = AaveInterface(getAaveProviderAddress()).getUserReserveData(token, msg.sender);
    }
}

contract AaveResolver is AaveHelpers {
    event LogDepositAave(address indexed token, uint256 tokenAmt);
    event LogWithdrawAave(address indexed token, uint256 tokenAmt);

    /**
     * @dev Deposit ETH/ERC20
     */
    function aaveDeposit(address token, uint amt) internal returns (uint _amt) {
        _amt = amt;
        AaveInterface aave = AaveInterface(getAaveAddress());

        uint ethAmt;
        if (token == getAddressETH()) {
            require(_amt == msg.value, "not-enought-eth");
            ethAmt = _amt;
        } else {
            TokenInterface tokenContract = TokenInterface(token);
            tokenContract.approve(getAaveProviderAddress(), _amt);
        }

        aave.setUserUseReserveAsCollateral(token, true);
        aave.deposit.value(ethAmt)(token, amt, 0); // TODO - need to set referralCode;

       emit LogDepositAave(token, _amt);
    }


    function aaveWithdraw(address token, uint amt) internal returns (uint _amt) {
        _amt = amt;

        AaveInterface aave = AaveInterface(getAaveAddress());
        uint totalBal = getWithdrawBalance(token);

        _amt = _amt == uint(-1) ? totalBal : _amt;
        uint _amtLeft = sub(totalBal, _amt);

        uint initialBal = token == getAddressETH() ? address(this).balance : TokenInterface(token).balanceOf(address(this));
        aave.redeemUnderlying(
            token,
            payable(address(this)),
            _amt,
            _amtLeft
        );
        uint finialBal = token == getAddressETH() ? address(this).balance : TokenInterface(token).balanceOf(address(this));
        uint withdrawnAmt = sub(finialBal, initialBal);
        require(withdrawnAmt >= _amt, "withdraw-error");

        emit LogWithdrawAave(token, _amt);
    }
}

contract LendingProxy is AaveResolver {
    string public name = "Compound-Aave";

    function deposit(uint lendingId, address token, uint256 amount) external payable returns (uint depositAmt) {
        if (lendingId == 1) {
            depositAmt = compoundDeposit(token, amount);
        } else if (lendingId == 2) {
            depositAmt = aaveDeposit(token, amount);
        } else {
            revert("not-vaild-lendingId");
        }
    }

    function withdraw(uint lendingId, address token, uint256 amount) external returns (uint withdrawAmt) {
        if (lendingId == 1) {
            withdrawAmt = compoundWithdraw(token, amount);
        } else if (lendingId == 2) {
            withdrawAmt = aaveWithdraw(token, amount);
        } else {
            revert("not-vaild-lendingId");
        }
    }
}