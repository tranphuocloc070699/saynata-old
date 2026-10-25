package db.migration;

import java.sql.ResultSet;
import java.sql.Statement;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

/**
 * TASK-116: a phrase can match from any of its words ("up" finds "give up"). The query is
 * {@code lower(source_text) LIKE '% up%'}, which a normal index cannot use; a trigram index can.
 *
 * A Java migration (like V19) because only Postgres has pg_trgm. H2 (the tests) does nothing here. If pg_trgm is
 * not installed on the server, nothing is created and the app still starts; the query is only slower.
 */
public class V37__phrase_word_start_trigram_index extends BaseJavaMigration {

    @Override
    public void migrate(Context context) throws Exception {
        boolean postgres = context.getConnection().getMetaData().getDatabaseProductName()
                .toLowerCase().contains("postgres");
        if (!postgres) {
            return;
        }
        try (Statement statement = context.getConnection().createStatement()) {
            try (ResultSet available = statement.executeQuery(
                    "SELECT 1 FROM pg_available_extensions WHERE name = 'pg_trgm'")) {
                if (!available.next()) {
                    return;
                }
            }
            statement.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm");
            statement.execute("CREATE INDEX idx_sentence_translation_source_trgm "
                    + "ON sentence_translation USING gin (lower(source_text) gin_trgm_ops)");
        }
    }
}
