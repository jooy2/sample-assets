// IDisposable and `using`: releasing a resource at the end of a scope,
// even when an exception cuts the scope short.

using System;
using System.IO;

sealed class TemporaryWorkspace : IDisposable
{
    private bool _disposed;

    public string Path { get; }

    public TemporaryWorkspace(string name)
    {
        Path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), name);
        Directory.CreateDirectory(Path);
        Console.WriteLine($"created {Path}");
    }

    public void Write(string fileName, string content)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        File.WriteAllText(System.IO.Path.Combine(Path, fileName), content);
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }
        _disposed = true;
        Directory.Delete(Path, recursive: true);
        Console.WriteLine($"removed {Path}");
    }
}

class DisposablePattern
{
    static void Main()
    {
        // Classic `using` block.
        using (var workspace = new TemporaryWorkspace("sample-assets-demo-1"))
        {
            workspace.Write("notes.txt", "one line");
            Console.WriteLine($"files: {Directory.GetFiles(workspace.Path).Length}");
        }

        // `using` declaration: disposed at the end of the enclosing scope.
        try
        {
            using var workspace = new TemporaryWorkspace("sample-assets-demo-2");
            workspace.Write("notes.txt", "another line");
            throw new InvalidOperationException("interrupted");
        }
        catch (InvalidOperationException error)
        {
            Console.WriteLine($"caught: {error.Message} (the workspace was still removed)");
        }
    }
}
