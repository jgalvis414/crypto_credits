// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/CompanyManager.sol"; // Adjust the import path as necessary
import {console} from "forge-std/console.sol";

contract CompanyManagerTest is Test {
    CompanyManager companyManager;
    address owner = address(1);
    address company = address(2);
    address user = address(3);

    function setUp() public {
        vm.prank(owner);
        companyManager = new CompanyManager();
    }

    function testRegisterCompany() public {
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        (bool isWhitelisted, , , , , , , ) = companyManager.companies(company);
        assertTrue(isWhitelisted);
    }

    function testAddFundsCompany() public {
        vm.prank(owner);
        companyManager.registerCompany(company, 10);
        vm.prank(company);
        vm.deal(company, 1 ether);
        companyManager.addFundsCompany{value: 1 ether}();
        (
            ,
            uint256 balance,
            ,
            ,
            ,
            ,
            uint256 creditBalance,
            uint256 availableBalance
        ) = companyManager.companies(company);
        assertEq(balance, 1 ether);
        assertEq(creditBalance, 0);
        assertEq(availableBalance, 1 ether - 0.1 ether);
    }

    function testWithdrawFundsCompany() public {
        // Step 1: Register a company and add funds
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        vm.prank(company);
        vm.deal(company, 1 ether);
        companyManager.addFundsCompany{value: 1 ether}();

        // Step 2: Verify the company's balance before withdrawal
        (, uint256 balanceBefore, , , , , , ) = companyManager.companies(
            company
        );
        assertEq(balanceBefore, 1 ether);

        // Step 3: Withdraw funds from the company
        vm.prank(company);
        companyManager.withdrawFundsCompany(0.5 ether);

        // Step 4: Verify the company's balance after withdrawal
        (, uint256 balanceAfter, , , , , , ) = companyManager.companies(
            company
        );
        assertEq(balanceAfter, 0.5 ether);

        // Step 5: Verify the company's ETH balance increased
        assertEq(company.balance, 0.5 ether);
    }

    function testWithdrawOwnerFunds() public {
        // Step 1: Register a company and add funds
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        vm.prank(company);
        vm.deal(company, 1 ether);
        companyManager.addFundsCompany{value: 1 ether}();

        // Step 2: Verify the owner's balance before withdrawal
        uint256 ownerBalanceBefore = companyManager.ownerBalance();
        assertEq(ownerBalanceBefore, 0.1 ether); // 10% of 1 ether

        // Step 3: Withdraw owner funds
        vm.prank(owner);
        companyManager.withdrawOwnerFunds(0.1 ether);

        // Step 4: Verify the owner's balance after withdrawal
        uint256 ownerBalanceAfter = companyManager.ownerBalance();
        assertEq(ownerBalanceAfter, 0);

        // Step 5: Verify the owner's ETH balance increased
        assertEq(owner.balance, 0.1 ether);
    }

    function testRegisterUser() public {
        vm.prank(owner);
        companyManager.registerCompany(company, 10);
        vm.prank(company);
        companyManager.registerUser(user);
        (address userOwner, , , ) = companyManager.users(user);
        assertEq(userOwner, user);
    }

    function testRegisterCredit() public {
        vm.prank(owner);
        companyManager.registerCompany(company, 10);
        vm.prank(company);
        vm.deal(company, 1 ether);
        companyManager.addFundsCompany{value: 1 ether}();
        vm.prank(company);
        companyManager.registerUser(user);
        vm.prank(company);
        companyManager.registerCredit(user, 0.5 ether, 5, 6);

        // Fetch the credit struct
        CompanyManager.Credit memory credit = companyManager.getCredit(0);
        assertEq(credit.id, 0);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 creditBalance,
            uint256 availableBalance
        ) = companyManager.companies(company);
        assertEq(creditBalance, 0.5 ether);
        assertEq(availableBalance, 0.9 ether - 0.5 ether);
    }

    function testAcceptCredit() public {
        // Step 1: Register a company and add funds
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        vm.prank(company);
        vm.deal(company, 1 ether);
        companyManager.addFundsCompany{value: 1 ether}();

        // Step 2: Register a user
        vm.prank(company);
        companyManager.registerUser(user);

        // Step 3: Register a credit for the user
        vm.prank(company);
        companyManager.registerCredit(user, 0.5 ether, 5, 6);

        // Step 4: User accepts the credit
        vm.prank(user);
        CompanyManager.Credit memory credit = companyManager.acceptCredit();
        assertTrue(credit.isActive);


        // Step 5: Verify the credit is active and the user has an active credit
        // CompanyManager.Credit memory credit = companyManager.getCredit(0);
        // assertTrue(credit.isActive);

        (, , bool hasActiveCredit, ) = companyManager.users(user);
        assertTrue(hasActiveCredit);

        // Step 6: Verify the installments were created
        uint256 creditId = 0;
        uint256 totalInstallments = 6;
        for (uint256 i = 0; i < totalInstallments; i++) {
            (, uint amount, , bool isPaid, , ) = companyManager.installments(
                creditId,
                i
            );
            assertEq(amount, 0.0875 ether);
            assertFalse(isPaid); // Ensure installments are not paid yet
        }

        // Step 7: Verify the user's stats were updated
        (
            ,
            ,
            uint256 creditsReceived,
            ,
            ,
            uint256 avaiableOnTimeScore
        ) = companyManager.userStats(user);
        assertEq(creditsReceived, 0.5 ether);
        assertEq(avaiableOnTimeScore, 0.525 ether);
    }

    function testPayInstallment() public {
        // Step 1: Register a company and add funds
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        vm.prank(company);
        vm.deal(company, 1 ether);
        companyManager.addFundsCompany{value: 1 ether}();

        // Step 2: Register a user
        vm.prank(company);
        companyManager.registerUser(user);

        // Step 3: Register a credit for the user
        vm.prank(company);
        companyManager.registerCredit(user, 0.5 ether, 5, 6);

        // Step 4: User accepts the credit
        vm.prank(user);
        companyManager.acceptCredit();

        // Step 5: User pays the first installment
        vm.prank(user);
        vm.deal(user, 0.1 ether); // Fund the user with enough ETH to pay the installment
        companyManager.payInstallment{value: 0.0875 ether}();

        // Step 6: Verify the installment is marked as paid
        (, , , bool isInstallmentPaid, , ) = companyManager.installments(0, 0);
        assertTrue(isInstallmentPaid);

        // Step 7: Verify the company's available balance is updated
        (
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 creditBalance,
            uint256 availableBalance
        ) = companyManager.companies(company);
        assertEq(creditBalance, 0.5 ether - 0.0875 ether);
        assertEq(availableBalance, 0.4 ether + 0.0875 ether);
    }

    function testPayAllInstallments() public {
        // Step 1: Register a company and add funds
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        vm.prank(company);
        vm.deal(company, 1 ether);
        companyManager.addFundsCompany{value: 1 ether}();

        // Step 2: Register a user
        vm.prank(company);
        companyManager.registerUser(user);

        // Step 3: Register a credit for the user
        vm.prank(company);
        companyManager.registerCredit(user, 0.5 ether, 5, 6);

        // Step 4: User accepts the credit
        vm.prank(user);
        companyManager.acceptCredit();

        // Step 5: User pays all installments
        vm.prank(user);
        vm.deal(user, 0.6 ether); // Fund the user with enough ETH to pay the installment
        companyManager.payInstallment{value: 0.0875 ether}();
        vm.prank(user);
        companyManager.payInstallment{value: 0.0875 ether}();
        vm.prank(user);
        companyManager.payInstallment{value: 0.0875 ether}();
        vm.prank(user);
        companyManager.payInstallment{value: 0.0875 ether}();
        vm.prank(user);
        companyManager.payInstallment{value: 0.0875 ether}();
        vm.prank(user);
        companyManager.payInstallment{value: 0.0875 ether}();

        // Step 6: Verify the installments are marked as paid
        (, , , bool isInstallmentPaid, , ) = companyManager.installments(0, 0);
        assertTrue(isInstallmentPaid);
        (, , , isInstallmentPaid, , ) = companyManager.installments(0, 1);
        assertTrue(isInstallmentPaid);
        (, , , isInstallmentPaid, , ) = companyManager.installments(0, 2);
        assertTrue(isInstallmentPaid);
        (, , , isInstallmentPaid, , ) = companyManager.installments(0, 3);
        assertTrue(isInstallmentPaid);
        (, , , isInstallmentPaid, , ) = companyManager.installments(0, 4);
        assertTrue(isInstallmentPaid);
        (, , , isInstallmentPaid, , ) = companyManager.installments(0, 5);
        assertTrue(isInstallmentPaid);

        // Step 7: Verify the company's available balance is updated
        (
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 creditBalance,
            uint256 availableBalance
        ) = companyManager.companies(company);
        assertEq(creditBalance, 0 ether);
        assertEq(availableBalance, 0.4 ether + 0.525 ether);

        // step 8: verify the user's stats were updated
        (
            ,
            ,
            uint256 creditsReceived,
            uint256 creditsPaid,
            uint256 score,
            uint256 avaiableOnTimeScore
        ) = companyManager.userStats(user);
        assertEq(creditsReceived, 0.5 ether);
        assertEq(creditsPaid, 0.525 ether);
        assertEq(score, 0.525 * 2 ether);
        assertEq(avaiableOnTimeScore, 0.525 ether);
    }

    function testRevertPayExtraInstallment() public {
        // Step 1: Register a company and add funds
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        vm.prank(company);
        vm.deal(company, 1 ether);
        companyManager.addFundsCompany{value: 1 ether}();

        // Step 2: Register a user
        vm.prank(company);
        companyManager.registerUser(user);

        // Step 3: Register a credit for the user
        vm.prank(company);
        companyManager.registerCredit(user, 0.5 ether, 5, 6);

        // Step 4: User accepts the credit
        vm.prank(user);
        companyManager.acceptCredit();

        // Step 5: User pays all installments
        vm.prank(user);
        vm.deal(user, 1 ether); // Fund the user with enough ETH to pay the installment
        companyManager.payInstallment{value: 0.0875 ether}();
        vm.prank(user);
        companyManager.payInstallment{value: 0.0875 ether}();
        vm.prank(user);
        companyManager.payInstallment{value: 0.0875 ether}();
        vm.prank(user);
        companyManager.payInstallment{value: 0.0875 ether}();
        vm.prank(user);
        companyManager.payInstallment{value: 0.0875 ether}();
        vm.prank(user);
        companyManager.payInstallment{value: 0.0875 ether}();
        vm.prank(user);
        vm.expectRevert("All installments are paid");
        companyManager.payInstallment{value: 0.0875 ether}();

    }

}
