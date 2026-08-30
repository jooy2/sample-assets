// A generic class with a type constraint, plus a generic method.

using System;
using System.Collections.Generic;
using System.Linq;

interface IIdentifiable
{
    int Id { get; }
}

class Product : IIdentifiable
{
    public int Id { get; init; }
    public string Name { get; init; } = "";
    public decimal Price { get; init; }

    public override string ToString() => $"#{Id} {Name} ({Price:C})";
}

class Repository<T> where T : class, IIdentifiable
{
    private readonly Dictionary<int, T> _items = new();

    public void Add(T item)
    {
        if (!_items.TryAdd(item.Id, item))
        {
            throw new InvalidOperationException($"id {item.Id} is already taken");
        }
    }

    public T? Find(int id) => _items.TryGetValue(id, out T? item) ? item : null;

    public bool Remove(int id) => _items.Remove(id);

    public IEnumerable<T> Where(Func<T, bool> predicate) => _items.Values.Where(predicate);

    public int Count => _items.Count;
}

class GenericRepository
{
    // A generic method infers its type argument from the call.
    static TValue LargestBy<TValue, TKey>(IEnumerable<TValue> values, Func<TValue, TKey> selector)
        where TKey : IComparable<TKey>
        => values.Aggregate((best, next) =>
            selector(next).CompareTo(selector(best)) > 0 ? next : best);

    static void Main()
    {
        var repository = new Repository<Product>();
        repository.Add(new Product { Id = 1, Name = "Matte Ceramic Mug", Price = 12.50m });
        repository.Add(new Product { Id = 2, Name = "Bamboo Desk Mat", Price = 32.00m });
        repository.Add(new Product { Id = 3, Name = "Cast Iron Skillet", Price = 59.00m });

        Console.WriteLine(repository.Find(2));
        Console.WriteLine($"not found: {repository.Find(99)?.ToString() ?? "(null)"}");

        foreach (var product in repository.Where(p => p.Price > 20))
        {
            Console.WriteLine($"over 20: {product}");
        }

        Console.WriteLine($"dearest: {LargestBy(repository.Where(_ => true), p => p.Price)}");
        Console.WriteLine($"count: {repository.Count}");
    }
}
