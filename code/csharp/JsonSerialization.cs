// Reading and writing JSON with System.Text.Json, which ships with the runtime.

using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

class Order
{
    [JsonPropertyName("order_id")]
    public string OrderId { get; set; } = "";

    [JsonPropertyName("user_id")]
    public int UserId { get; set; }

    [JsonPropertyName("total")]
    public decimal Total { get; set; }

    [JsonPropertyName("status")]
    public string Status { get; set; } = "";

    [JsonPropertyName("shipped_at")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public DateTime? ShippedAt { get; set; }
}

class JsonSerialization
{
    static void Main()
    {
        var options = new JsonSerializerOptions { WriteIndented = true };

        var orders = new List<Order>
        {
            new() { OrderId = "ORD-10001", UserId = 82, Total = 104.35m, Status = "delivered",
                    ShippedAt = new DateTime(2025, 11, 3, 9, 15, 0, DateTimeKind.Utc) },
            new() { OrderId = "ORD-10002", UserId = 6, Total = 42.99m, Status = "pending" },
        };

        string json = JsonSerializer.Serialize(orders, options);
        Console.WriteLine(json);

        List<Order>? parsed = JsonSerializer.Deserialize<List<Order>>(json);
        Console.WriteLine($"\nparsed {parsed?.Count} orders");

        // Reading a document without a matching class.
        using JsonDocument document = JsonDocument.Parse(json);
        foreach (JsonElement element in document.RootElement.EnumerateArray())
        {
            string id = element.GetProperty("order_id").GetString() ?? "?";
            decimal total = element.GetProperty("total").GetDecimal();
            Console.WriteLine($"{id} {total:C}");
        }
    }
}
