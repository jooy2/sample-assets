// Running work on a thread pool and collecting the results, rather than
// starting raw threads.

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

public class ThreadsExecutor {

    static int countPrimes(int limit) {
        boolean[] composite = new boolean[limit + 1];
        int found = 0;

        for (int candidate = 2; candidate <= limit; candidate++) {
            if (composite[candidate]) {
                continue;
            }
            found++;
            for (long multiple = (long) candidate * candidate; multiple <= limit; multiple += candidate) {
                composite[(int) multiple] = true;
            }
        }
        return found;
    }

    public static void main(String[] args) throws InterruptedException, ExecutionException {
        List<Integer> limits = List.of(50_000, 120_000, 30_000, 200_000, 90_000, 10_000);

        try (ExecutorService pool = Executors.newFixedThreadPool(4)) {
            List<Callable<String>> tasks = new ArrayList<>();
            for (int limit : limits) {
                tasks.add(() -> limit + " has " + countPrimes(limit) + " primes");
            }

            for (Future<String> future : pool.invokeAll(tasks)) {
                System.out.println(future.get());
            }
        }

        // An atomic counter needs no lock for a single read-modify-write.
        AtomicInteger processed = new AtomicInteger();
        try (ExecutorService pool = Executors.newFixedThreadPool(4)) {
            for (int i = 0; i < 100; i++) {
                pool.submit(processed::incrementAndGet);
            }
            pool.shutdown();
            pool.awaitTermination(2, TimeUnit.SECONDS);
        }
        System.out.println("processed " + processed.get());

        // CompletableFuture composes asynchronous steps without blocking.
        CompletableFuture<String> pipeline = CompletableFuture
                .supplyAsync(() -> countPrimes(60_000))
                .thenApply(count -> count * 2)
                .thenApply(doubled -> "twice the primes below 60000 is " + doubled);

        System.out.println(pipeline.join());
    }
}
