package com.englishtranslation.backend.lines;

import java.util.concurrent.Executor;
import java.util.concurrent.ThreadPoolExecutor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.stereotype.Component;

/**
 * Runs the background fill of the other languages after the language row got its fast answer (doc-7, 2026-11-04).
 * One worker thread; when 100 fills already wait, a new one is dropped (the next learner in that language just
 * asks again). With {@code app.lines.fill-in-background=false} (tests) a fill runs at once, in the caller's thread.
 */
@Component
public class LineFill {

    private final Executor executor;

    public LineFill(@Value("${app.lines.fill-in-background:true}") boolean inBackground) {
        if (inBackground) {
            ThreadPoolTaskExecutor pool = new ThreadPoolTaskExecutor();
            pool.setCorePoolSize(1);
            pool.setMaxPoolSize(1);
            pool.setQueueCapacity(100);
            pool.setThreadNamePrefix("line-fill-");
            pool.setRejectedExecutionHandler(new ThreadPoolExecutor.DiscardPolicy());
            pool.setWaitForTasksToCompleteOnShutdown(true);
            pool.setAwaitTerminationSeconds(30);
            pool.initialize();
            this.executor = pool;
        } else {
            this.executor = Runnable::run;
        }
    }

    public void run(Runnable fill) {
        executor.execute(fill);
    }
}
