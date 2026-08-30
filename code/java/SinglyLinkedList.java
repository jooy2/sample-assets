// A generic singly linked list that can be walked with a for-each loop.

import java.util.Iterator;
import java.util.NoSuchElementException;
import java.util.StringJoiner;

public class SinglyLinkedList<T> implements Iterable<T> {

    private static final class Node<T> {
        final T value;
        Node<T> next;

        Node(T value, Node<T> next) {
            this.value = value;
            this.next = next;
        }
    }

    private Node<T> head;
    private int size;

    public void addFirst(T value) {
        head = new Node<>(value, head);
        size++;
    }

    public void addLast(T value) {
        Node<T> node = new Node<>(value, null);
        if (head == null) {
            head = node;
        } else {
            Node<T> last = head;
            while (last.next != null) {
                last = last.next;
            }
            last.next = node;
        }
        size++;
    }

    public T removeFirst() {
        if (head == null) {
            throw new NoSuchElementException("the list is empty");
        }
        T value = head.value;
        head = head.next;
        size--;
        return value;
    }

    public boolean contains(T value) {
        for (T held : this) {
            if (held.equals(value)) {
                return true;
            }
        }
        return false;
    }

    public void reverse() {
        Node<T> previous = null;
        Node<T> current = head;

        while (current != null) {
            Node<T> next = current.next;
            current.next = previous;
            previous = current;
            current = next;
        }
        head = previous;
    }

    public int size() {
        return size;
    }

    @Override
    public Iterator<T> iterator() {
        return new Iterator<>() {
            private Node<T> cursor = head;

            @Override
            public boolean hasNext() {
                return cursor != null;
            }

            @Override
            public T next() {
                if (cursor == null) {
                    throw new NoSuchElementException();
                }
                T value = cursor.value;
                cursor = cursor.next;
                return value;
            }
        };
    }

    @Override
    public String toString() {
        StringJoiner joiner = new StringJoiner(" -> ", "[", "]");
        for (T value : this) {
            joiner.add(String.valueOf(value));
        }
        return joiner.toString();
    }

    public static void main(String[] args) {
        SinglyLinkedList<String> lines = new SinglyLinkedList<>();
        lines.addLast("Amber");
        lines.addLast("Cobalt");
        lines.addLast("Emerald");
        lines.addFirst("Crimson");

        System.out.println(lines + " (size " + lines.size() + ")");
        System.out.println("contains Cobalt: " + lines.contains("Cobalt"));
        System.out.println("removed " + lines.removeFirst());

        lines.reverse();
        System.out.println("reversed " + lines);
    }
}
