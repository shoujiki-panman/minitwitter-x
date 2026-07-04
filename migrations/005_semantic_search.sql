-- 005: 意味検索（pgvector）を追加する
-- キーワード一致でなく「意味が近い」ツイートを探せるようにする。
-- SupabaseのSQL Editorに貼って実行する（1回だけ）。

-- pgvector拡張を有効化（ベクトル型と近傍検索が使えるようになる）
create extension if not exists vector;

-- tweetsに埋め込みベクトル列を追加
-- text-embedding-3-small は 1536 次元なので vector(1536)
alter table tweets add column if not exists embedding vector(1536);

-- 近傍検索を速くする索引（コサイン距離）。件数が少ないうちは無くても動く。
create index if not exists tweets_embedding_idx
  on tweets using ivfflat (embedding vector_cosine_ops) with (lists = 100);

-- 質問ベクトルに意味が近い「公開ツイート」を返す関数
-- RLSは呼び出したユーザーの権限で効くので、公開ツイートだけが返る。
create or replace function match_tweets(query_embedding vector(1536), match_count int default 10)
returns table (
  id bigint,
  user_id uuid,
  body text,
  created_at timestamptz,
  similarity float
)
language sql stable
as $$
  select
    t.id,
    t.user_id,
    t.body,
    t.created_at,
    1 - (t.embedding <=> query_embedding) as similarity   -- 1に近いほど意味が近い
  from tweets t
  where t.is_public = true
    and t.embedding is not null
  order by t.embedding <=> query_embedding                -- <=> はコサイン距離
  limit match_count;
$$;
