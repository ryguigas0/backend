defmodule CambiatusWeb.Schema.Resolvers.AccountsTest do
  @moduledoc """
  This module integration tests to for resolvers that work with the accounts context
  """
  use Cambiatus.ApiCase

  alias Cambiatus.{Accounts.User, Commune.Transfer}

  describe "Accounts Resolver" do
    test "collects a user account given the account name" do
      assert Repo.aggregate(User, :count, :account) == 0
      user = insert(:user)

      conn = build_conn() |> auth_user(user)

      variables = %{
        "account" => user.account
      }

      query = """
      query($account: String!){
        user(account: $account) {
          account
          avatar
          bio
        }
      }
      """

      res = conn |> get("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "user" => profile
        }
      } = json_response(res, 200)

      assert Repo.aggregate(User, :count, :account) == 1
      assert profile["account"] == user.account
    end

    test "fetches user address" do
      assert Repo.aggregate(User, :count, :account) == 0
      address = insert(:address)
      user = address.account

      conn = build_conn() |> auth_user(user)

      variables = %{
        "account" => user.account
      }

      query = """
      query($account: String!) {
        user(account: $account) {
          account
          address { zip }
        }
      }
      """

      res = conn |> get("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "user" => profile
        }
      } = json_response(res, 200)

      assert Repo.aggregate(User, :count, :account) == 1
      assert profile["account"] == user.account
      assert profile["address"]["zip"] == address.zip
    end

    test "fetches user KYC data" do
      assert Repo.aggregate(User, :count, :account) == 0
      kyc = insert(:kyc_data)
      user = kyc.account
      conn = build_conn() |> auth_user(user)

      variables = %{
        "account" => user.account
      }

      query = """
      query($account: String!){
        user(account: $account) {
          account
          kyc { userType }
        }
      }
      """

      res = conn |> get("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "user" => profile
        }
      } = json_response(res, 200)

      assert Repo.aggregate(User, :count, :account) == 1
      assert profile["account"] == user.account
      assert profile["kyc"]["userType"] == kyc.user_type
    end

    test "updates a user account details given the account name" do
      assert Repo.aggregate(User, :count, :account) == 0
      user = insert(:user)
      conn = build_conn() |> auth_user(user)

      variables = %{
        "input" => %{
          "bio" => "new bio"
        }
      }

      query = """
      mutation($input: UserUpdateInput!){
        updateUser(input: $input) {
          account
          bio
        }
      }
      """

      res = conn |> post("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "updateUser" => profile
        }
      } = json_response(res, 200)

      assert Repo.aggregate(User, :count, :account) == 1
      assert profile["account"] == user.account
      refute profile["bio"] == user.bio
    end
  end

  describe "payment history" do
    setup do
      assert Repo.aggregate(User, :count, :account) == 0
      assert Repo.aggregate(Transfer, :count, :id) == 0

      utc_today = DateTime.utc_now()
      utc_yesterday = DateTime.add(utc_today, 24 * 60 * 60)

      user1 = insert(:user, %{account: "user1"})
      user2 = insert(:user, %{account: "user2"})

      transfers = [
        # user1 -> user2
        insert(:transfer, %{from: user1, to: user2, created_at: utc_today}),
        insert(:transfer, %{from: user1, to: user2, created_at: utc_today}),
        insert(:transfer, %{from: user1, to: user2, created_at: utc_yesterday}),

        # user1 <- user2
        insert(:transfer, %{from: user2, to: user1, created_at: utc_today})
      ]

      assert Repo.aggregate(User, :count, :account) == 2
      assert Repo.aggregate(Transfer, :count, :id) == 4

      %{
        :users => [user1, user2],
        :transfers => transfers,
        :variables => %{
          # tests are based on the `user1` profile
          "account" => user1.account,
          first: Enum.count(transfers)
        }
      }
    end

    test "receiving transfers", %{variables: variables} do
      query = """
        query ($account: String!) {
          user(account: $account) {
            transfers(
              first: #{variables.first},
              filter: {
                direction: { direction: RECEIVING }
              }) {
              count
            }
          }
        }
      """

      user = insert(:user)
      conn = build_conn() |> auth_user(user)

      res = conn |> get("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "user" => %{
            "transfers" => %{
              "count" => user1_incoming_transfers_count
            }
          }
        }
      } = json_response(res, 200)

      assert user1_incoming_transfers_count == 1
    end

    test "outgoing transfers", %{variables: variables} do
      user = insert(:user)
      conn = build_conn() |> auth_user(user)

      query = """
        query ($account: String!) {
          user(account: $account) {
            transfers(
              first: #{variables.first},
              filter: {
                direction: { direction: SENDING }
              }) {
              count
            }
          }
        }
      """

      res = conn |> get("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "user" => %{
            "transfers" => %{
              "count" => user1_outgoing_transfers_count
            }
          }
        }
      } = json_response(res, 200)

      assert user1_outgoing_transfers_count == 3
    end

    test "transfers for the date", %{variables: variables} do
      user = insert(:user)
      conn = build_conn() |> auth_user(user)
      today_date = Date.to_string(Date.utc_today())

      query = """
        query ($account: String!) {
          user(account: $account) {
            transfers(
              first: #{variables.first},
              filter: {
               date: "#{today_date}"
              }) {
              count
            }
          }
        }
      """

      res = conn |> get("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "user" => %{
            "transfers" => %{
              "count" => user1_today_transfers_count
            }
          }
        }
      } = json_response(res, 200)

      assert user1_today_transfers_count == 3
    end

    test "receiving transfers for the date", %{variables: variables} do
      today_date = Date.to_string(Date.utc_today())

      user = insert(:user)
      conn = build_conn() |> auth_user(user)

      query = """
        query ($account: String!) {
          user(account: $account) {
           transfers(
             first: #{variables.first},
             filter: {
              direction: { direction: RECEIVING },
              date: "#{today_date}"
             }) {
              count
            }
          }
        }
      """

      res = conn |> get("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "user" => %{
            "transfers" => %{
              "count" => user1_today_incoming_transfers_count
            }
          }
        }
      } = json_response(res, 200)

      assert user1_today_incoming_transfers_count == 1
    end

    test "outgoing transfers for the date", %{variables: variables} do
      today_date = Date.to_string(Date.utc_today())

      user = insert(:user)
      conn = build_conn() |> auth_user(user)

      query = """
        query ($account: String!) {
          user(account: $account) {
            transfers(
              first: #{variables.first},
              filter: {
                direction: { direction: SENDING },
                date: "#{today_date}"
              }) {
              count
            }
          }
        }
      """

      res = conn |> get("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "user" => %{
            "transfers" => %{
              "count" => user1_today_outgoing_transfers_count
            }
          }
        }
      } = json_response(res, 200)

      assert user1_today_outgoing_transfers_count == 2
    end

    test "receiving transfers for the date from user2 to user1", %{
      users: _users,
      variables: variables
    } do
      today_date = Date.utc_today() |> Date.to_string()

      user = insert(:user)
      conn = build_conn() |> auth_user(user)

      query = """
        query ($account: String!) {
          user(account: $account) {
            transfers(
              first: #{variables.first},
              filter: {
                direction: {direction: RECEIVING, otherAccount: "user2"},
                date: "#{today_date}"
              }
            ) {
              count
              edges {
                node {
                  from {
                    account
                  }
                  to {
                    account
                  }
                }
              }
            }
          }
        }
      """

      res = conn |> get("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "user" => %{
            "transfers" => %{
              "count" => transfers_from_user2_to_user1_for_today_count,
              "edges" => collected_transfers
            }
          }
        }
      } = json_response(res, 200)

      get_account = & &1["node"][&2]["account"]

      assert Enum.all?(
               collected_transfers,
               fn t -> get_account.(t, "from") == "user2" && get_account.(t, "to") == "user1" end
             ) == true

      assert transfers_from_user2_to_user1_for_today_count == 1
    end

    test "outgoing transfers for the date from user1 to user2", %{
      users: _users,
      variables: variables
    } do
      user = insert(:user)
      conn = build_conn() |> auth_user(user)

      today_date = Date.utc_today() |> Date.to_string()

      query = """
        query ($account: String!) {
          user(account: $account) {
            transfers(
              first: #{variables.first},
              filter: {
                direction: {direction: SENDING, otherAccount: "user2"},
                date: "#{today_date}"
              }
            ) {
              count
              edges {
                node {
                  from {
                    account
                  }
                  to {
                    account
                  }
                }
              }
            }
          }
        }
      """

      res = conn |> get("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "user" => %{
            "transfers" => %{
              "count" => transfers_from_user1_to_user2_for_today_count,
              "edges" => collected_transfers
            }
          }
        }
      } = json_response(res, 200)

      get_account = & &1["node"][&2]["account"]

      assert Enum.all?(
               collected_transfers,
               fn t -> get_account.(t, "from") == "user1" && get_account.(t, "to") == "user2" end
             ) == true

      assert transfers_from_user1_to_user2_for_today_count == 2
    end

    test "list of payers to `user1`", %{users: users, variables: variables} do
      user = insert(:user)
      conn = build_conn() |> auth_user(user)

      [_, user2] = users

      query = """
      query ($account: String!) {
        user(account: $account) {
          getPayersByAccount(account: "#{user2.account}") {
            account
            name
            avatar
          }
        }
      }
      """

      res = conn |> get("/api/graph", query: query, variables: variables)

      %{
        "data" => %{
          "user" => %{
            "getPayersByAccount" => payers
          }
        }
      } = json_response(res, 200)

      %{"account" => account, "avatar" => avatar, "name" => name} = hd(payers)

      assert account == user2.account
      assert avatar == user2.avatar
      assert name == user2.name
    end
  end
end
