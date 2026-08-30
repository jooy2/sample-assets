// Struct tags map Go field names onto JSON keys, in both directions.

package main

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

type Order struct {
	OrderID   string     `json:"order_id"`
	UserID    int        `json:"user_id"`
	Total     float64    `json:"total"`
	Status    string     `json:"status"`
	ShippedAt *time.Time `json:"shipped_at,omitempty"`
	internal  string     // unexported fields are never serialised
}

func main() {
	shipped := time.Date(2025, time.November, 3, 9, 15, 0, 0, time.UTC)

	orders := []Order{
		{OrderID: "ORD-10001", UserID: 82, Total: 104.35, Status: "delivered", ShippedAt: &shipped},
		{OrderID: "ORD-10002", UserID: 6, Total: 42.99, Status: "pending", internal: "hidden"},
	}

	encoded, err := json.MarshalIndent(orders, "", "  ")
	if err != nil {
		fmt.Println("encode failed:", err)
		return
	}
	fmt.Println(string(encoded))

	var decoded []Order
	if err := json.Unmarshal(encoded, &decoded); err != nil {
		fmt.Println("decode failed:", err)
		return
	}
	fmt.Printf("\ndecoded %d orders, first is %s\n", len(decoded), decoded[0].OrderID)

	// Without a struct, JSON lands in map[string]any.
	var loose []map[string]any
	if err := json.Unmarshal(encoded, &loose); err == nil {
		// Numbers arrive as float64 unless a decoder is told otherwise.
		total, _ := loose[0]["total"].(float64)
		fmt.Printf("loose read: %v costs %.2f\n", loose[0]["order_id"], total)
	}

	// Streaming, one value at a time, from any io.Reader.
	stream := strings.NewReader(`{"order_id":"ORD-10003","total":18.5}` + "\n" +
		`{"order_id":"ORD-10004","total":73.2}`)

	decoder := json.NewDecoder(stream)
	for decoder.More() {
		var order Order
		if err := decoder.Decode(&order); err != nil {
			fmt.Println("stream failed:", err)
			break
		}
		fmt.Printf("streamed %s %.2f\n", order.OrderID, order.Total)
	}

	if err := json.Unmarshal([]byte(`{"total": "free"}`), &Order{}); err != nil {
		fmt.Println("\ntype mismatch:", err)
	}
}
