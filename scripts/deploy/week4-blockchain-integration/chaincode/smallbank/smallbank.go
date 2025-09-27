package main

import (
    "encoding/json"
    "fmt"
    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmartContract struct {
    contractapi.Contract
}

type Account struct {
    ID      string `json:"id"`
    Balance int    `json:"balance"`
}

func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
    accounts := []Account{
        {ID: "account1", Balance: 1000000},
        {ID: "account2", Balance: 2000000},
        {ID: "account3", Balance: 1500000},
        {ID: "account4", Balance: 3000000},
        {ID: "account5", Balance: 2500000},
    }

    for _, account := range accounts {
        accountJSON, err := json.Marshal(account)
        if err != nil {
            return err
        }
        err = ctx.GetStub().PutState(account.ID, accountJSON)
        if err != nil {
            return fmt.Errorf("failed to put to world state: %v", err)
        }
    }
    return nil
}

func (s *SmartContract) Balance(ctx contractapi.TransactionContextInterface, accountID string) (*Account, error) {
    accountJSON, err := ctx.GetStub().GetState(accountID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if accountJSON == nil {
        return nil, fmt.Errorf("account %s does not exist", accountID)
    }

    var account Account
    err = json.Unmarshal(accountJSON, &account)
    if err != nil {
        return nil, err
    }
    return &account, nil
}

func (s *SmartContract) Transfer(ctx contractapi.TransactionContextInterface, fromAccountID string, toAccountID string, amount int) error {
    if amount <= 0 {
        return fmt.Errorf("transfer amount must be positive")
    }

    fromAccount, err := s.Balance(ctx, fromAccountID)
    if err != nil {
        return err
    }
    
    toAccount, err := s.Balance(ctx, toAccountID)
    if err != nil {
        return err
    }

    if fromAccount.Balance < amount {
        return fmt.Errorf("insufficient balance in account %s", fromAccountID)
    }

    fromAccount.Balance -= amount
    toAccount.Balance += amount

    fromAccountJSON, err := json.Marshal(fromAccount)
    if err != nil {
        return err
    }
    err = ctx.GetStub().PutState(fromAccountID, fromAccountJSON)
    if err != nil {
        return err
    }

    toAccountJSON, err := json.Marshal(toAccount)
    if err != nil {
        return err
    }
    err = ctx.GetStub().PutState(toAccountID, toAccountJSON)
    if err != nil {
        return err
    }

    return nil
}

func main() {
    assetChaincode, err := contractapi.NewChaincode(&SmartContract{})
    if err != nil {
        fmt.Printf("Error creating smallbank chaincode: %v", err)
        return
    }

    if err := assetChaincode.Start(); err != nil {
        fmt.Printf("Error starting smallbank chaincode: %v", err)
    }
}
