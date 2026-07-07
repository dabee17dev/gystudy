-- gystudy 랭킹 스키마
-- Supabase 대시보드 → SQL Editor 에 붙여넣고 실행하세요.
-- (anon 키로는 테이블 생성이 불가하므로 대시보드에서 1회 실행이 필요합니다.)

-- 0) 플레이어(닉네임) 테이블 — 비밀번호 없는 가입/로그인용
-- 신원 = (반, 이름) 조합. 같은 이름이라도 반이 다르면 다른 사람으로 취급
create table if not exists public.players (
    id          bigint generated always as identity primary key,
    nickname    text        not null,
    class       int         not null,
    created_at  timestamptz not null default now(),
    constraint players_nick_chk check (char_length(nickname) between 1 and 12),
    constraint players_unique unique (nickname, class)
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
    category    text        not null default 'all', -- 문제 종류: 'all' | '속담' | '관용어'
    class       int,                             -- 반. 옛 기록은 null(미배정)일 수 있음
    created_at  timestamptz not null default now(),
    constraint scores_solved_chk    check (solved >= 0 and solved <= attempted * 10),
    constraint scores_difficulty_chk check (difficulty in ('easy','hard')),
    constraint scores_time_chk      check (time_limit > 0),
    constraint scores_category_chk  check (category in ('all','속담','관용어')),
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

-- 7) 마이그레이션: 기존 테이블에 문제 종류(category) 컬럼 추가 (랭킹에 전체/속담만/관용어만 표시용)
alter table public.scores add column if not exists category text not null default 'all';
alter table public.scores drop constraint if exists scores_category_chk;
alter table public.scores add constraint scores_category_chk check (category in ('all','속담','관용어'));

-- 8) 마이그레이션(중요): 반(class) 컬럼 추가.
--    여러 반이 접속해 같은 이름이 겹치는 문제를 막기 위해, 이제 신원은 (반, 이름) 조합입니다.
--    기존 players의 nickname 단독 유니크 제약을 제거하고 (nickname, class) 조합으로 교체합니다.
alter table public.players add column if not exists class int;
alter table public.players drop constraint if exists players_nickname_key; -- 예전 "unique" 인라인 제약의 기본 이름
alter table public.players drop constraint if exists players_unique;
alter table public.players add constraint players_unique unique (nickname, class);

alter table public.scores add column if not exists class int;

-- 8-1) 기존 데이터 보정: "5반"으로 시작하는 닉네임만 5반으로 표시합니다.
--      그 외 기존 기록은 어느 반인지 알 수 없으므로 class를 null(미배정)로 남겨둡니다.
--      (다른 반 학생도 접속했을 수 있어, 함부로 우리 반으로 단정하지 않습니다.)
update public.players set class = 5 where class is null and nickname like '5반%';
update public.scores  set class = 5 where class is null and nickname like '5반%';
