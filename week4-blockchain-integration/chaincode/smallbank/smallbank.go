package main

import (
	"encoding/json"
	"fmt"
	"strconv"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmallbankContract struct {
	contractapi.Contract
}

type Account struct {
	ID             string  `json:"id"`
	CheckingBalance float64 `json:"checkingBalance"`
	SavingsBalance  float64 `json:"savingsBalance"`
	Owner          string  `json:"owner"`
	Created        string  `json:"created"`
}

func (s *SmallbankContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	accounts := []Account{
		{ID: "account1", CheckingBalance: 1000.0, SavingsBalance: 500.0, Owner: "Alice", Created: "2024-01-01"},
		{ID: "account2", CheckingBalance: 2000.0, SavingsBalance: 1000.0, Owner: "Bob", Created: "2024-01-01"},
		{ID: "account3", CheckingBalance: 1500.0, SavingsBalance: 750.0, Owner: "Charlie", Created: "2024-01-01"},
	}

	for _, account := range accounts {
		accountJSON, err := json.Marshal(account)
		if err != nil {
			return err
		}

		err = ctx.GetStub().PutState(account.ID, accountJSON)
		if err != nil {
			return fmt.Errorf("failed to put account %s to world state: %v", account.ID, err)
		}
	}

	return nil
}

func (s *SmallbankContract) CreateAccount(ctx contractapi.TransactionContextInterface, id string, checkingBalance float64, savingsBalance float64, owner string) error {
	account := Account{
		ID:              id,
		CheckingBalance: checkingBalance,
		SavingsBalance:  savingsBalance,
		Owner:           owner,
		Created:         ctx.GetStub().GetTxTimestamp().String(),
	}
	accountJSON, err := json.Marshal(account)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(id, accountJSON)
}

func (s *SmallbankContract) Transfer(ctx contractapi.TransactionContextInterface, fromAccountID string, toAccountID string, amount float64) error {
	if amount <= 0 {
		return fmt.Errorf("transfer amount must be positive")
	}

	fromAccountJSON, err := ctx.GetStub().GetState(fromAccountID)
	if err != nil {
		return fmt.Errorf("failed to read from account %s: %v", fromAccountID, err)
	}
	if fromAccountJSON == nil {
		return fmt.Errorf("account %s does not exist", fromAccountID)
	}

	toAccountJSON, err := ctx.GetStub().GetState(toAccountID)
	if err != nil {
		return fmt.Errorf("failed to read to account %s: %v", toAccountID, err)
	}
	if toAccountJSON == nil {
		return fmt.Errorf("account %s does not exist", toAccountID)
	}

	var fromAccount Account
	err = json.Unmarshal(fromAccountJSON, &fromAccount)
	if err != nil {
		return err
	}

	var toAccount Account
	err = json.Unmarshal(toAccountJSON, &toAccount)
	if err != nil {
		return err
	}

	if fromAccount.CheckingBalance < amount {
		return fmt.Errorf("insufficient balance in account %s", fromAccountID)
	}

	fromAccount.CheckingBalance -= amount
	toAccount.CheckingBalance += amount

	fromAccountJSON, err = json.Marshal(fromAccount)
	if err != nil {
		return err
	}

	toAccountJSON, err = json.Marshal(toAccount)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(fromAccountID, fromAccountJSON)
	if err != nil {
		return err
	}

	return ctx.GetStub().PutState(toAccountID, toAccountJSON)
}

func (s *SmallbankContract) GetBalance(ctx contractapi.TransactionContextInterface, accountID string) (float64, error) {
	accountJSON, err := ctx.GetStub().GetState(accountID)
	if err != nil {
		return 0, fmt.Errorf("failed to read from world state: %v", err)
	}
	if accountJSON == nil {
		return 0, fmt.Errorf("account %s does not exist", accountID)
	}

	var account Account
	err = json.Unmarshal(accountJSON, &account)
	if err != nil {
		return 0, err
	}

	return account.CheckingBalance + account.SavingsBalance, nil
}

func main() {
	smallbankContract := new(SmallbankContract)
	cc, err := contractapi.NewChaincode(smallbankContract)
	if err != nil {
		panic(err.Error())
	}

	if err := cc.Start(); err != nil {
		panic(err.Error())
	}
}
