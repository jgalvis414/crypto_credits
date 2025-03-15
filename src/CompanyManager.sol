// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import {console} from "forge-std/console.sol";

// import "hardhat/console.sol";

contract CompanyManager {
    address public owner;

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
    ) public {
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

    constructor() {
        owner = msg.sender;
        creditCounter = 0;
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
            "Company is not actived"
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

    function addFundsCompany() external payable onlyActive onlyWhitelisted {
        uint256 _ownerAmount = (msg.value * companies[msg.sender].protocolFee) /
            100;
        companies[msg.sender].balance += msg.value;
        companies[msg.sender].avaiableBalance += msg.value - _ownerAmount;
        ownerBalance += _ownerAmount;
    }

    function withdrawFundsCompany(
        uint256 _amount
    ) external onlyActive onlyWhitelisted {
        require(
            companies[msg.sender].balance >= _amount,
            "No hay suficiente fondos"
        );
        companies[msg.sender].balance -= _amount;
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Transferencia fallida");
    }

    function withdrawOwnerFunds(uint256 _amount) external onlyOwner {
        require(ownerBalance >= _amount, "No hay suficiente fondos");
        ownerBalance -= _amount;
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Transferencia fallida");
        ownerBalance = 0;
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

    function payInstallment() external payable {
        require(
            recentCredits[msg.sender].isActive == true,
            "El credito no esta activo"
        );
        uint256 _creditId = recentCredits[msg.sender].id;
        uint256 _installmentId = 0;
        bool _isPaid = true;

        for (uint256 i = 0; i < installments[_creditId].length; i++) {
            if (installments[_creditId][i].isPaid == false) {
                _isPaid = false;
                _installmentId = i;
                break;
            }
        }

        require(!_isPaid, "All installments are paid");

        require(
            msg.value == installments[_creditId][_installmentId].amount,
            "El monto pagado no es correcto"
        );

        uint256 _date = installments[_creditId][_installmentId].date;

        installments[_creditId][_installmentId].isPaid = true;
        installments[_creditId][_installmentId].date = block.timestamp;

        installments[_creditId][_installmentId].score = msg.value;

        companies[credits[_creditId].lender].avaiableBalance += msg.value;
        unchecked {
            if (
                msg.value > companies[credits[_creditId].lender].creditBalance
            ) {
                companies[credits[_creditId].lender].creditBalance = 0;
            } else {
                companies[credits[_creditId].lender].creditBalance -= msg.value;
            }
        }
        uint256 scoreIncrement;
        if (block.timestamp < (_date - 5 days)) {
            scoreIncrement = msg.value * 2;
        } else if (block.timestamp < (_date + 1 minutes)) {
            scoreIncrement = msg.value;
        } else {
            scoreIncrement = msg.value;
        }

        installments[_creditId][_installmentId].score += scoreIncrement;
        userStats[credits[_creditId].user].score += scoreIncrement;
        userStats[credits[_creditId].user].creditsPaid += msg.value;

        if (_installmentId == credits[_creditId].totalInstallments - 1) {
            credits[_creditId].isPaid = true;
            credits[_creditId].isActive = false;
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
        sendViaCall(msg.sender, recentCredits[msg.sender].amount);
        return credits[_creditId];
    }

    function sendViaCall(address _to, uint256 _amount) public returns (bool) {
        (bool success, ) = _to.call{value: _amount}(""); // Send Ether
        require(success, "Call failed");
        return success;
    }
}
