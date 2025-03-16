// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {console} from "forge-std/console.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract CompanyManager {
    address public owner;
    IERC20 public usdc;
    uint256 public creditCounter;
    uint256 public ownerBalance;

    struct Company {
        bool isWhitelisted;
        uint256 balance;
        uint256 premium;
        address companyAddress;
        bool isActive;
        uint256 protocolFee;
        uint256 creditBalance;
        uint256 avaiableBalance;
    }

    mapping(address => Company) public companies;

    struct User {
        address owner;
        uint256 creditScore;
        bool hasActiveCredit;
        address registerBy;
    }

    struct UserStats {
        bool exists;
        address user;
        uint256 creditsReceived;
        uint256 creditsPaid;
        uint256 score;
        uint256 avaiableOnTimeScore;
    }

    mapping(address => UserStats) public userStats;

    struct Credit {
        address user;
        uint256 amount; // monto prestado
        address lender;
        uint256 rate; // %5
        uint256 nextInstallmentDate;
        uint256 totalInstallments;
        uint256 protocolFee;
        uint256 totalAmount; // motno + fee + interes
        uint256 id;
        bool isActive;
        bool isPaid;
    }

    struct installment {
        uint256 creditId;
        uint256 amount;
        uint256 numberInstallment;
        bool isPaid;
        uint256 score;
        uint256 date;
    }

    mapping(uint256 creditId => installment[]) public installments;

    function addInstallment(
        uint256 key,
        uint256 _amount,
        uint256 _numberInstallment
    ) internal {
        installment memory newInstallment = installment({
            creditId: key,
            amount: _amount,
            numberInstallment: _numberInstallment,
            isPaid: false,
            score: _amount,
            date: block.timestamp + (30 days * (_numberInstallment + 1))
        });

        // Agregar el nuevo installment al array dentro del mapping
        installments[key].push(newInstallment);
    }

    mapping(uint256 creditId => Credit) public credits;
    mapping(address user => Credit) public recentCredits;

    mapping(address user => User) public users;

    constructor(address _usdcAddress) {
        owner = msg.sender;
        creditCounter = 0;
        usdc = IERC20(_usdcAddress);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyWhitelisted() {
        require(
            companies[msg.sender].isWhitelisted == true,
            "Company is not whitelisted"
        );
        _;
    }

    modifier onlyActive() {
        require(
            companies[msg.sender].isActive == true,
            "Company is not active"
        );
        _;
    }

    function registerCompany(
        address _companyAddress,
        uint256 _protocolFee
    ) external onlyOwner {
        companies[_companyAddress].isWhitelisted = true;
        companies[_companyAddress].companyAddress = _companyAddress;
        companies[_companyAddress].isActive = true;
        companies[_companyAddress].balance = 0;
        companies[_companyAddress].creditBalance = 0;
        companies[_companyAddress].avaiableBalance = 0;
        companies[_companyAddress].protocolFee = _protocolFee;
    }

    function addFundsCompany(
        uint256 _amount
    ) external onlyActive onlyWhitelisted {
        // Transfer USDC from the caller to the contract
        require(
            usdc.transferFrom(msg.sender, address(this), _amount),
            "USDC transfer failed"
        );

        // Calculate the owner's share (protocol fee)
        uint256 _ownerAmount = (_amount * companies[msg.sender].protocolFee) /
            100;

        // Update the company's balance and available balance
        companies[msg.sender].balance += _amount - _ownerAmount;
        companies[msg.sender].avaiableBalance += _amount - _ownerAmount;

        // Update the owner's balance
        ownerBalance += _ownerAmount;
    }

    function withdrawFundsCompany(
        uint256 _amount
    ) external onlyActive onlyWhitelisted {
        // Ensure the company has sufficient balance
        require(
            companies[msg.sender].balance >= _amount,
            "No hay suficiente fondos"
        );

        // Update the company's balance
        companies[msg.sender].balance -= _amount;

        // Transfer USDC tokens to the company
        bool success = usdc.transfer(msg.sender, _amount);
        require(success, "Transferencia fallida");
    }

    function withdrawOwnerFunds(uint256 _amount) external onlyOwner {
        require(ownerBalance >= _amount, "No hay suficiente fondos");
        ownerBalance -= _amount;
        bool success = usdc.transfer(msg.sender, _amount);
        require(success, "Transferencia fallida");
    }

    function registerUser(
        address _userAddress
    ) external onlyActive onlyWhitelisted {
        users[_userAddress].owner = _userAddress;
        users[_userAddress].hasActiveCredit = false;
        users[_userAddress].registerBy = msg.sender;
        userStats[msg.sender].exists = true;
    }

    function registerCredit(
        address _user,
        uint256 _amount,
        uint256 _rate,
        uint256 _totalInstallments
    ) external onlyActive onlyWhitelisted {
        require(
            companies[msg.sender].avaiableBalance >= _amount,
            "Fondos insuficientes"
        );
        require(
            users[_user].hasActiveCredit == false,
            "El usuario ya tiene creditos activos"
        );
        require(
            _rate > 0 && _totalInstallments >= 4,
            "Las opciones ingresadas no son validas"
        );

        companies[msg.sender].avaiableBalance -= _amount;
        companies[msg.sender].creditBalance += _amount;
        userStats[msg.sender].exists = true;
        userStats[msg.sender].creditsReceived += _amount;

        Credit memory credit;

        credit.id = creditCounter;
        credit.user = _user;
        credit.amount = _amount; // monto prestado
        credit.lender = msg.sender; // pago por 0% de intereses
        credit.rate = _rate; /* %5 */
        credit.nextInstallmentDate = block.timestamp + 30 days; // fecha del primer pago por el periodo
        credit
            .totalInstallments = _totalInstallments; /* cuantas cuotas se prestan */
        credit.protocolFee = companies[msg.sender].protocolFee;
        credit.totalAmount = _amount + ((_amount * _rate) / 100);

        credits[creditCounter] = credit;
        recentCredits[_user] = credit;

        creditCounter++;
    }

    function payInstallment(uint256 _amount) external {
        require(
            recentCredits[msg.sender].isActive == true,
            "El credito no esta activo"
        );
        uint256 _creditId = recentCredits[msg.sender].id;
        uint256 _installmentId = 0;

        for (uint256 i = 0; i < installments[_creditId].length; i++) {
            if (installments[_creditId][i].isPaid == false) {
                _installmentId = i;
                break;
            }
        }

        require(
            _amount == installments[_creditId][_installmentId].amount,
            "El monto pagado no es correcto"
        );
        require(
            usdc.transferFrom(msg.sender, address(this), _amount),
            "USDC transfer failed"
        );

        uint256 _date = installments[_creditId][_installmentId].date;

        installments[_creditId][_installmentId].isPaid = true;
        installments[_creditId][_installmentId].date = block.timestamp;

        installments[_creditId][_installmentId].score = _amount;

        companies[credits[_creditId].lender].avaiableBalance += _amount;
        unchecked {
            if (_amount >= companies[credits[_creditId].lender].creditBalance) {
                companies[credits[_creditId].lender].creditBalance = 0;
            } else {
                companies[credits[_creditId].lender].creditBalance -= _amount;
            }
        }
        uint256 scoreIncrement;
        if (block.timestamp < (_date - 5 days)) {
            scoreIncrement = _amount * 2;
        } else if (block.timestamp < (_date + 1 minutes)) {
            scoreIncrement = _amount;
        } else {
            scoreIncrement = _amount;
        }

        installments[_creditId][_installmentId].score += scoreIncrement;
        userStats[credits[_creditId].user].score += scoreIncrement;
        userStats[credits[_creditId].user].creditsPaid += _amount;

        if (_installmentId == credits[_creditId].totalInstallments - 1) {
            credits[_creditId].isPaid = true;
            credits[_creditId].isActive = false;
            recentCredits[credits[_creditId].user].isActive = false;
            recentCredits[credits[_creditId].user].isPaid = true;
            users[credits[_creditId].user].hasActiveCredit = false;
        }
    }

    function getCredit(uint256 _creditId) public view returns (Credit memory) {
        return credits[_creditId];
    }

    function acceptCredit() external returns (Credit memory) {
        require(
            users[msg.sender].hasActiveCredit == false,
            "El usuario ya tiene creditos activos"
        );
        require(
            recentCredits[msg.sender].user == msg.sender,
            "El credito no pertenece al usuario"
        );

        users[msg.sender].hasActiveCredit = true;
        recentCredits[msg.sender].isActive = true;
        uint256 _creditId = recentCredits[msg.sender].id;
        credits[_creditId].isActive = true;

        for (
            uint256 i = 0;
            i < recentCredits[msg.sender].totalInstallments;
            i++
        ) {
            addInstallment(
                _creditId,
                recentCredits[msg.sender].totalAmount /
                    recentCredits[msg.sender].totalInstallments,
                i
            );
        }

        userStats[msg.sender].creditsReceived += recentCredits[msg.sender]
            .amount;
        userStats[msg.sender].avaiableOnTimeScore += recentCredits[msg.sender]
            .totalAmount;
        bool success = usdc.transfer(
            msg.sender,
            recentCredits[msg.sender].amount
        );
        require(success, "Transferencia fallida");
        return credits[_creditId];
    }

    function sendViaCall(address _to, uint256 _amount) public returns (bool) {
        (bool success, ) = _to.call{value: _amount}(""); // Send Ether
        require(success, "Call failed");
        return success;
    }
}
