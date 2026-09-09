alter table "public"."games" drop constraint "games_away_team_id_fkey";

alter table "public"."games" drop constraint "games_home_team_id_fkey";

alter table "public"."games" add constraint "games_away_team_id_fkey" FOREIGN KEY (away_team_id) REFERENCES public.teams(id) ON UPDATE CASCADE ON DELETE SET DEFAULT not valid;

alter table "public"."games" validate constraint "games_away_team_id_fkey";

alter table "public"."games" add constraint "games_home_team_id_fkey" FOREIGN KEY (home_team_id) REFERENCES public.teams(id) ON UPDATE CASCADE ON DELETE SET DEFAULT not valid;

alter table "public"."games" validate constraint "games_home_team_id_fkey";


