        account = Current.user&.account
        if account.nil?

          return render json: { errors: ["Your account is not ready."] },
                        status: :unprocessable_entity
