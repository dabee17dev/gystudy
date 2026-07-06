-- gystudy 랭킹 스키마
-- Supabase 대시보드 → SQL Editor 에 붙여넣고 실행하세요.
-- (anon 키로는 테이블 생성이 불가하므로 대시보드에서 1회 실행이 필요합니다.)

-- 0) 플레이어(닉네임) 테이블 — 비밀번호 없는 가입/로그인용
create table if not exists public.players (
    id          bigint generated always as identity primary key,
    nickname    text        not null unique,
    created_at  timestamptz not null default now(),
    constraint players_nick_chk check (char_length(nickname) between 1 and 12)
);

alter table public.players enable row level security;
drop policy if exists "public read players"   on public.players;
drop policy if exists "public insert players" on public.players;
create policy "public read players"   on public.players for select using (true);
create policy "public insert players" on public.players for insert with check (true);

-- 1) 점수(게임 결과) 테이블
create table if not exists public.scores (
    id          bigint generated always as identity primary key,
    nickname    text        not null,
    mode        int         not null,            -- 1~4 퀴즈 모드
    difficulty  text        not null,            -- 'easy' | 'hard'
    time_limit  int         not null,            -- 제한시간(초). 현재 앱은 100초로 고정, 과거값(60/120)도 허용
    solved      int         not null,            -- 획득 점수 (문제당 최대 10점, 힌트 사용 시 5점)
    attempted   int         not null,            -- 시도 개수
    accuracy    real,                            -- 정답률(0~1), 점수와 별개로 계산됨
    created_at  timestamptz not null default now(),
    constraint scores_solved_chk    check (solved >= 0 and solved <= attempted * 10),
    constraint scores_difficulty_chk check (difficulty in ('easy','hard')),
    constraint scores_time_chk      check (time_limit > 0),
    constraint scores_nick_chk      check (char_length(nickname) between 1 and 12)
);

-- 2) 리더보드 조회 최적화 인덱스 (게임(mode)·난이도별로 비교, 시간은 더 이상 랭킹 구분에 쓰이지 않음)
create index if not exists idx_scores_leaderboard
    on public.scores (mode, difficulty, solved desc, accuracy desc, created_at asc);

-- 3) RLS: 누구나 읽기/쓰기(삽입) 가능
alter table public.scores enable row level security;

drop policy if exists "public read scores"   on public.scores;
drop policy if exists "public insert scores" on public.scores;

create policy "public read scores"
    on public.scores for select
    using (true);

create policy "public insert scores"
    on public.scores for insert
    with check (true);

-- 참고: 수정/삭제(update/delete) 정책은 일부러 열지 않았습니다.
--       (누구나 남의 기록을 지우거나 조작하는 것을 막기 위함)
--       필요하면 아래 주석을 해제하세요. (권장하지 않음)
-- create policy "public update scores" on public.scores for update using (true) with check (true);
-- create policy "public delete scores" on public.scores for delete using (true);

-- 4) 마이그레이션: 기존 테이블이 이미 있다면(solved=정답 개수 시절 제약) 아래를 실행해
--    solved(=점수, 문제당 최대 10점)에 맞게 제약을 갱신하세요.
alter table public.scores drop constraint if exists scores_solved_chk;
alter table public.scores add constraint scores_solved_chk
    check (solved >= 0 and solved <= attempted * 10);

-- 5) 마이그레이션: 제한시간을 100초로 고정하며 time_limit 제약을 완화
alter table public.scores drop constraint if exists scores_time_chk;
alter table public.scores add constraint scores_time_chk check (time_limit > 0);

-- 6) 마이그레이션(중요): 이 버전 이전에 저장된 기록은 solved가 "정답 개수"였습니다.
--    (문제당 10점 체계 도입 전 데이터) 아래 조건에 해당하는 옛 기록을 점수 기준으로 보정합니다.
--    - solved가 5의 배수가 아니면 100% 옛 데이터이므로 반드시 필요합니다.
--    - 이미 점수 체계로 저장된 최신 기록까지 다시 곱하지 않도록, 먼저 데이터를 확인한 뒤 실행하세요.
-- update public.scores set solved = solved * 10 where solved % 5 <> 0;
