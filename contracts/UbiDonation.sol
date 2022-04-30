// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./JaxOwnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface UBI {
    function deposit_reward(uint amount) external;
}

contract UbiDonation is Initializable, JaxOwnable, ReentrancyGuardUpgradeable {
        
    using SafeERC20 for IERC20;

    IERC20 public wjax;
    uint public ubi_admin_fee;

    UBI ubi;

    address[] ubi_admins;
    mapping(uint => bool) ubi_admin_status;
    mapping(address => uint) ubi_admin_to_ids;
    
    event Donate(uint amount, uint ubi_admin_id);
    event Deposit_UBI(uint wjax_amount);
    event Set_Ubi_Admin_Fee(uint ubi_admin_fee);
    event Add_Ubi_Admins(address[] ubi_admins);
    event Delete_Ubi_Admins(uint[] ubi_admin_ids);
    event Withdraw_By_Owner(address token, uint amount);

    modifier checkZeroAddress(address account) {
        require(account != address(0x0), "Only non-zero address");
        _;
    }

    function initialize(IERC20 _wjax, UBI _ubi) external initializer checkZeroAddress(address(_wjax)) checkZeroAddress(address(_ubi)) {
        __ReentrancyGuard_init();
        wjax = _wjax;
        ubi = _ubi;
        ubi_admin_fee = 5; // 5%
        require(wjax.approve(address(ubi), type(uint).max), "Wjax approvement failed");
        _transferOwnership(msg.sender);
    }

    function donate(uint amount, uint ubi_admin_id) external nonReentrant {
        wjax.safeTransferFrom(msg.sender, address(this), amount);
        if(ubi_admin_status[ubi_admin_id])
            wjax.safeTransfer(ubi_admins[ubi_admin_id], amount * ubi_admin_fee / 100);
        emit Donate(amount, ubi_admin_id);
    }

    function set_ubi_admin_fee(uint _ubi_admin_fee) external onlyOwner {
        require(_ubi_admin_fee >= 1 && _ubi_admin_fee <= 5, "Ubi admin fee should be 1% - 5%");
        ubi_admin_fee = _ubi_admin_fee;
        emit Set_Ubi_Admin_Fee(_ubi_admin_fee);
    }

    function _add_ubi_admin(address ubi_admin) internal checkZeroAddress(ubi_admin) {
        uint ubi_admin_id = ubi_admin_to_ids[ubi_admin];
        if( ubi_admin_id == 0) {
            ubi_admin_id = ubi_admins.length;
            ubi_admins.push(ubi_admin);
            ubi_admin_to_ids[ubi_admin] = ubi_admin_id;
        }
        ubi_admin_status[ubi_admin_id] = true;
    }

    function add_ubi_admins(address[] memory _ubi_admins) external onlyOwner {
        uint i = 0;
        for(; i < _ubi_admins.length; i += 1) {
            _add_ubi_admin(_ubi_admins[i]);
        }
        emit Add_Ubi_Admins(_ubi_admins);
    }

    function delete_Ubi_Admins(uint[] memory _ubi_admin_ids) external onlyOwner {
        uint i = 0;
        for(; i < _ubi_admin_ids.length; i += 1) {
            ubi_admin_status[_ubi_admin_ids[i]] = false;
        }
        emit Delete_Ubi_Admins(_ubi_admin_ids);
    }

    function get_ubi_admin_status(uint id) external view returns(bool) {
        require(id < ubi_admins.length, "Invalid admin id");
        return ubi_admin_status[id];
    }

    function get_ubi_admin(uint id) external view returns(address) {
        require(id < ubi_admins.length, "Invalid admin id");
        return ubi_admins[id];
    }

    function get_ubi_admins() external view returns(address[] memory) {
        return ubi_admins;
    }

    function withdrawByOwner(address token, uint amount) external onlyOwner nonReentrant {
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdraw_By_Owner(token, amount);
    }   

    function deposit_UBI() external nonReentrant {
        uint wjax_balance = wjax.balanceOf(address(this));
        require(wjax_balance > 0, "Nothing to deposit");
        ubi.deposit_reward(wjax_balance);
        emit Deposit_UBI(wjax_balance);
    }
}