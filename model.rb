
module Model

    def verify_token(token)
        begin
            decoded_token = JWT.decode token, 'ojojoj!', true, { algorithm: 'HS256' }
            return true, decoded_token
        rescue JWT::DecodeError
            return false, nil
        end
    end

    def db_initiate()
        db = SQLite3::Database.new('db/database.db')
        db.results_as_hash = true
        db.execute('PRAGMA foreign_keys = ON')
        return db
    end
    
    def data_cases(db)
        return db.execute("SELECT * FROM cases")
    end

    def balance_data(db, decoded_token)
        return db.execute("SELECT balance FROM user WHERE id = ?", decoded_token[0]['sub'])
    end

    def mail_userdata(db, decoded_token)
        return db.execute("SELECT email FROM user WHERE id = ?", decoded_token[0]['sub'])
    end

    def item_data(db, decoded_token)
        return db.execute("SELECT * FROM u_item WHERE user_id = ?", decoded_token[0]['sub'])
    end

    def user_item_rel(db, decoded_token)
        return db.execute("SELECT item.name, u_item.user_id FROM u_item LEFT JOIN item ON u_item.item_id = item.id WHERE u_item.user_id = ?", decoded_token[0]['sub'])
    end

    def user_rarity_rel(db, decoded_token)
        return db.execute("SELECT item.rarity_class, u_item.user_id FROM u_item LEFT JOIN item ON u_item.item_id = item.id WHERE u_item.user_id = ?", decoded_token[0]['sub'])
    end

    def user_data(db)
        return db.execute("SELECT * FROM user")
    end

    def admin_status(db, decoded_token)
        return db.execute("SELECT admin FROM user WHERE id = ?", decoded_token[0]['sub'])
    end

    def reg_user(db, email, password, starting_balance)
        db.execute("INSERT INTO user (email, password, balance) VALUES (?, ?, ?)", email, password, starting_balance)
    end

    def user_email_data(db, email)
        return db.execute("SELECT * FROM user WHERE email = ?", email)
    end

    def deleteuser(db, user_id)
        return db.execute("DELETE FROM user WHERE id = #{user_id}")
    end

    def user_id_get(db, decoded_token)
        return db.execute("SELECT id FROM user WHERE id = ?", decoded_token[0]['sub'])
    end 

    def get_balance(db, user_id)
        if user_id.is_a? Array
            return db.execute("SELECT balance FROM user WHERE id = #{user_id[0]["id"]}")
        else
            return db.execute("SELECT balance FROM user WHERE id = #{user_id}")
        end
    end

    def get_case_price(db, caseid)
        return db.execute("SELECT buy_price FROM cases WHERE id = #{caseid}")
    end

    def get_itemid(db, caseid, rarity)
        return db.execute("SELECT id FROM item WHERE case_id = #{caseid} AND rarity_class = #{rarity}")
    end

    def get_bprice(db, item_id)
        return db.execute("SELECT base_price FROM item WHERE id = #{item_id[0]["id"]}")
    end

    def new_item(db, user_id, item_id, condition_float, price)
        db.execute("INSERT INTO u_item (user_id, item_id, condition_float, price) VALUES (?, ?, ?, ?)", user_id[0]["id"], item_id[0]["id"], condition_float, price)
    end

    def get_uitemid(db, itemid, decoded_token)
        return db.execute("SELECT id FROM u_item WHERE user_id = ? AND id = #{itemid}", decoded_token[0]['sub'])
    end

    def get_itemprice(db,itemid)
        return db.execute("SELECT price FROM u_item WHERE id = #{itemid}")
    end

    def deleteitem(db, items_id)
        db.execute("DELETE FROM u_item WHERE id = #{items_id[0]['id']}")
    end

    def balance_change(action, amount, user_id)

        db = db_initiate()

        current_balance = get_balance(db, user_id)

        if action == "remove"
            new_balance = (current_balance[0]["balance"] - amount).round(3)
        elsif action == "add"
            new_balance = (current_balance[0]["balance"] + amount).round(3)
        end

        db.execute("UPDATE user SET balance = #{new_balance} WHERE id = #{user_id}")

        db.close
    end
end