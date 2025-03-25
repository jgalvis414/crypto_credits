// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/CompanyManager.sol"; // Adjust the import path as necessary
import {console} from "forge-std/console.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract CompanyManagerTest is Test {
    CompanyManager companyManager;
    MockUSDC usdc;
    address owner = address(1);
    address company = address(2);
    address user = address(3);

    function setUp() public {
        usdc = new MockUSDC();
        vm.prank(owner);
        companyManager = new CompanyManager(address(usdc));
    }

    function testRegisterCompany() public {
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        (
            bool isWhitelisted,
            uint256 balance,
            uint256 premium,
            address companyAddress,
            bool isActive,
            uint256 protocolFee,
            uint256 creditBalance,
            uint256 avaiableBalance
        ) = companyManager.companies(company);
        assertTrue(isWhitelisted);
        assertTrue(isActive);
        assertEq(balance, 0);
        assertEq(premium, 0);
        assertEq(companyAddress, company);
        assertEq(protocolFee, 10);
        assertEq(creditBalance, 0);
        assertEq(avaiableBalance, 0);
    }

    function testAddFundsCompany() public {
        usdc.transfer(company, 100 * 10 ** usdc.decimals()); // Transfer 100 USDC to the company
        // Step 1: Register a company
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee

        // Step 2: Approve the CompanyManager to spend USDC on behalf of the company
        vm.startPrank(company);
        usdc.approve(address(companyManager), 100 * 10 ** usdc.decimals()); // Approve 100 USDC

        // Step 3: Add funds to the company using USDC
        companyManager.addFundsCompany(100 * 10 ** usdc.decimals());
        vm.stopPrank();

        // Step 4: Verify the company's balance and available balance
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
        assertEq(balance, 90 * 10 ** usdc.decimals());
        assertEq(creditBalance, 0);
        assertEq(availableBalance, 90 * 10 ** usdc.decimals()); // 90% of 100 USDC

        // Step 5: Verify the owner's balance
        uint256 ownerBalance = companyManager.ownerBalance();
        assertEq(ownerBalance, 10 * 10 ** usdc.decimals()); // 10% of 100 USDC
    }

    function testWithdrawFundsCompany() public {
        usdc.transfer(company, 100 * 10 ** usdc.decimals()); // Transfer 100 USDC to the company
        // Step 1: Register a company and add funds
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee

        // Step 2: Approve the CompanyManager to spend USDC on behalf of the company
        vm.startPrank(company);
        usdc.approve(address(companyManager), 100 * 10 ** usdc.decimals()); // Approve 100 USDC

        // Step 3: Add funds to the company using USDC
        companyManager.addFundsCompany(100 * 10 ** usdc.decimals());

        // Step 4: Verify the company's balance before withdrawal
        (, uint256 balanceBefore, , , , , , ) = companyManager.companies(
            company
        );
        assertEq(balanceBefore, 90 * 10 ** usdc.decimals());

        // Step 5: Withdraw funds from the company
        companyManager.withdrawFundsCompany(50 * 10 ** usdc.decimals());
        vm.stopPrank();

        // Step 6: Verify the company's balance after withdrawal
        (
        ,
        uint256 balanceAfter,
        ,
        ,
        ,
        ,
        ,
        uint256 avaiableBalance
) = companyManager.companies(
            company
        );
        assertEq(balanceAfter, 40 * 10 ** usdc.decimals());
        assertEq(avaiableBalance, 40 * 10 ** usdc.decimals());

        assertEq(usdc.balanceOf(company), 50 * 10 ** usdc.decimals());
    }

    function testWithdrawOwnerFunds() public {
        usdc.transfer(company, 100 * 10 ** usdc.decimals()); // Transfer 100 USDC to the company
        // Step 1: Register a company and add funds
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee

        // Step 2: Approve the CompanyManager to spend USDC on behalf of the company
        vm.startPrank(company);
        usdc.approve(address(companyManager), 100 * 10 ** usdc.decimals()); // Approve 100 USDC

        // Step 3: Add funds to the company using USDC
        companyManager.addFundsCompany(100 * 10 ** usdc.decimals());
        vm.stopPrank();

        // Step 2: Verify the owner's balance before withdrawal
        uint256 ownerBalanceBefore = companyManager.ownerBalance();
        assertEq(ownerBalanceBefore, 10 * 10 ** usdc.decimals()); // 10% of 100 USDC

        // Step 3: Withdraw owner funds
        vm.startPrank(owner);
        companyManager.withdrawOwnerFunds(10 * 10 ** usdc.decimals());
        vm.stopPrank();

        // Step 4: Verify the owner's balance after withdrawal
        uint256 ownerBalanceAfter = companyManager.ownerBalance();
        assertEq(ownerBalanceAfter, 0);

        // Step 5: Verify the owner's ETH balance increased
        assertEq(usdc.balanceOf(owner), 10 * 10 ** usdc.decimals());
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
        usdc.transfer(company, 100 * 10 ** usdc.decimals()); // Transfer 100 USDC to the company
        // Step 1: Register a company
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        // Step 2: Approve the CompanyManager to spend USDC on behalf of the company
        vm.startPrank(company);
        usdc.approve(address(companyManager), 100 * 10 ** usdc.decimals()); // Approve 100 USDC
        // Step 3: Add funds to the company using USDC
        companyManager.addFundsCompany(100 * 10 ** usdc.decimals());
        companyManager.registerUser(user);
        companyManager.registerCredit(user, 50 * 10 ** usdc.decimals(), 5, 6);
        vm.stopPrank();

        // Fetch the credit struct
        (
            address creditUser,
            uint256 amount,
            address lender,
            uint256 rate,
            uint256 nextInstallmentDate,
            uint256 totalInstallments,
            uint256 protocolFee,
            uint256 totalAmount,
            uint256 id,
            bool isActive,
            bool isPaid
        ) = companyManager.credits(0);
        assertEq(id, 0);
        assertEq(creditUser, user);
        assertEq(amount, 50 * 10 ** usdc.decimals());
        assertEq(lender, company);
        assertEq(rate, 5);
        assertEq(nextInstallmentDate, block.timestamp + 30 days);
        assertEq(totalInstallments, 6);
        assertEq(protocolFee, 10);
        assertEq(
            totalAmount,
            50 * 10 ** usdc.decimals() + (50 * 10 ** usdc.decimals() * 5) / 100
        );
        assertEq(isActive, false);
        assertEq(isPaid, false);

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
        assertEq(creditBalance, 50 * 10 ** usdc.decimals());
        assertEq(availableBalance, 40 * 10 ** usdc.decimals());
    }

    function testAcceptCredit() public {
        usdc.transfer(company, 100 * 10 ** usdc.decimals()); // Transfer 100 USDC to the company
        // Step 1: Register a company
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        // Step 2: Approve the CompanyManager to spend USDC on behalf of the company
        vm.startPrank(company);
        usdc.approve(address(companyManager), 100 * 10 ** usdc.decimals()); // Approve 100 USDC
        // Step 3: Add funds to the company using USDC
        companyManager.addFundsCompany(100 * 10 ** usdc.decimals());
        companyManager.registerUser(user);
        companyManager.registerCredit(user, 50 * 10 ** usdc.decimals(), 5, 6);
        vm.stopPrank();

        // Step 4: User accepts the credit
        vm.prank(user);
        CompanyManager.Credit memory credit = companyManager.acceptCredit();
        assertTrue(credit.isActive);

        (, , bool hasActiveCredit, ) = companyManager.users(user);
        assertTrue(hasActiveCredit);

        // Step 5: Verify the installments were created
        uint256 creditId = 0;
        uint256 totalInstallments = 6;
        for (uint256 i = 0; i < totalInstallments; i++) {
            (, uint amount, , bool isPaid, , ) = companyManager.installments(
                creditId,
                i
            );
            assertEq(amount, 875 * 10 ** (usdc.decimals() - 2));
            assertFalse(isPaid); // Ensure installments are not paid yet
        }

        // Step 6: Verify the user's stats were updated
        (
            ,
            ,
            uint256 creditsReceived,
            ,
            ,
            uint256 avaiableOnTimeScore
        ) = companyManager.userStats(user);
        assertEq(creditsReceived, 50 * 10 ** usdc.decimals());
        assertEq(avaiableOnTimeScore, 525 * 10 ** (usdc.decimals() - 1));
    }

    function testPayInstallment() public {
        usdc.transfer(company, 100 * 10 ** usdc.decimals()); // Transfer 100 USDC to the company
        usdc.transfer(user, 100 * 10 ** usdc.decimals()); // Transfer 100 USDC to the company
        // Step 1: Register a company
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        // Step 2: Approve the CompanyManager to spend USDC on behalf of the company
        vm.startPrank(company);
        usdc.approve(address(companyManager), 100 * 10 ** usdc.decimals()); // Approve 100 USDC
        // Step 3: Add funds to the company using USDC
        companyManager.addFundsCompany(100 * 10 ** usdc.decimals());
        companyManager.registerUser(user);
        companyManager.registerCredit(user, 50 * 10 ** usdc.decimals(), 5, 6);
        vm.stopPrank();

        // Step 4: User accepts the credit
        vm.startPrank(user);
        CompanyManager.Credit memory credit = companyManager.acceptCredit();
        assertTrue(credit.isActive);
        (, uint256 balanceBefore, , , , , , ) = companyManager.companies(
            company
        );

        // Step 5: User pays the first installment
        usdc.approve(
            address(companyManager),
            875 * 10 ** (usdc.decimals() - 2)
        );
        companyManager.payInstallment(875 * 10 ** (usdc.decimals() - 2));
        vm.stopPrank();

        // Step 6: Verify the installment is marked as paid
        (, , , bool isInstallmentPaid, , ) = companyManager.installments(0, 0);
        assertTrue(isInstallmentPaid);

        // Step 7: Verify the company's available balance is updated
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
        assertEq(
            creditBalance,
            50 * 10 ** (usdc.decimals()) - 875 * 10 ** (usdc.decimals() - 2)
        );
        assertEq(
            availableBalance,
            40 * 10 ** (usdc.decimals()) + 875 * 10 ** (usdc.decimals() - 2)
        );
        assertEq(
            balance,
            balanceBefore +
                875 *
                10 ** (usdc.decimals() - 2)
        );
    }

    function testPayAllInstallments() public {
        usdc.transfer(company, 100 * 10 ** usdc.decimals()); // Transfer 100 USDC to the company
        usdc.transfer(user, 100 * 10 ** usdc.decimals()); // Transfer 100 USDC to the company
        // Step 1: Register a company
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        // Step 2: Approve the CompanyManager to spend USDC on behalf of the company
        vm.startPrank(company);
        usdc.approve(address(companyManager), 100 * 10 ** usdc.decimals()); // Approve 100 USDC
        // Step 3: Add funds to the company using USDC
        companyManager.addFundsCompany(100 * 10 ** usdc.decimals());
        companyManager.registerUser(user);
        companyManager.registerCredit(user, 50 * 10 ** usdc.decimals(), 5, 6);
        vm.stopPrank();

        // Step 4: User accepts the credit
        vm.startPrank(user);
        CompanyManager.Credit memory credit = companyManager.acceptCredit();
        assertTrue(credit.isActive);

        // Step 5: User pays the installments
        uint256 amount = 875 * 10 ** (usdc.decimals() - 2);
        for (uint256 i = 0; i < 6; i++) {
            usdc.approve(address(companyManager), amount);
            companyManager.payInstallment(amount);
        }
        vm.stopPrank();

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
        assertEq(creditBalance, 0);
        assertEq(
            availableBalance,
            40 * 10 ** (usdc.decimals()) + 525 * 10 ** (usdc.decimals() - 1)
        );

        // step 8: verify the user's stats were updated
        (
            ,
            ,
            uint256 creditsReceived,
            uint256 creditsPaid,
            uint256 score,
            uint256 avaiableOnTimeScore
        ) = companyManager.userStats(user);
        assertEq(creditsReceived, 50 * 10 ** usdc.decimals());
        assertEq(creditsPaid, 525 * 10 ** (usdc.decimals() - 1));
        assertEq(score, 525 * 10 ** (usdc.decimals() - 1) * 2);
        assertEq(avaiableOnTimeScore, 525 * 10 ** (usdc.decimals() - 1));
        // verify the credit is not active
        (, , , , , , , , , bool isActive, bool isPaid) = companyManager
            .recentCredits(user);
        assertFalse(isActive);
        assertTrue(isPaid);
    }

    function testRevertPayExtraInstallment() public {
        usdc.transfer(company, 100 * 10 ** usdc.decimals()); // Transfer 100 USDC to the company
        usdc.transfer(user, 100 * 10 ** usdc.decimals()); // Transfer 100 USDC to the company
        // Step 1: Register a company
        vm.prank(owner);
        companyManager.registerCompany(company, 10); // 10% protocol fee
        // Step 2: Approve the CompanyManager to spend USDC on behalf of the company
        vm.startPrank(company);
        usdc.approve(address(companyManager), 100 * 10 ** usdc.decimals()); // Approve 100 USDC
        // Step 3: Add funds to the company using USDC
        companyManager.addFundsCompany(100 * 10 ** usdc.decimals());
        companyManager.registerUser(user);
        companyManager.registerCredit(user, 50 * 10 ** usdc.decimals(), 5, 6);
        vm.stopPrank();

        // Step 4: User accepts the credit
        vm.startPrank(user);
        CompanyManager.Credit memory credit = companyManager.acceptCredit();
        assertTrue(credit.isActive);

        // Step 5: User pays the first installment
        uint256 amount = 875 * 10 ** (usdc.decimals() - 2);
        for (uint256 i = 0; i < 6; i++) {
            usdc.approve(address(companyManager), amount);
            companyManager.payInstallment(amount);
        }
        usdc.approve(address(companyManager), amount);
        vm.expectRevert("El credito no esta activo");
        companyManager.payInstallment(amount);
        vm.stopPrank();
    }
}
