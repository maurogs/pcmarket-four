module Api
  module V1
    class CheckoutsController < BaseController
      before_action :authenticate!

      def create
        unless Setting.enabled?("checkout_enabled")
          return render_error("checkout_disabled", t("api.errors.checkout_disabled"),
                              status: :forbidden)
        end

        summary = CartSummary.for(user: current_user)
        @form = ::Checkout::Form.new(summary: summary, user: current_user, **checkout_params)

        unless @form.valid?
          @error_details = @form.errors.to_hash.transform_values { |messages| Array(messages) }
          return render_error("validation_failed", t("api.errors.validation_failed"),
                              status: :unprocessable_entity, details: @error_details)
        end

        @orders = ::Checkout::PlaceOrder.new(form: @form, summary: summary).call
        @payment_method = @form.payment_method
        @redirect_url = start_payment(@orders)
        @payment_instructions = payment_instructions(@orders)

        render :create, formats: :json, status: :created
      rescue ::Checkout::PlaceOrder::Error => error
        render_error("checkout_failed", t("checkout.errors.#{error.message_key}"),
                     status: :unprocessable_entity)
      end

      private

      def checkout_params
        params.permit(
          :email, :payment_method, :address_id, :save_address, :terms_accepted,
          :withdrawal_acknowledged, :checkout_token, :full_name, :line1, :line2, :city,
          :postal_code, :region_id, :country_code, :phone, :success_url, :cancel_url,
          delivery: {}
        ).to_h.symbolize_keys.except(:success_url, :cancel_url)
      end

      def start_payment(orders)
        return nil if orders.empty? || @payment_method == "bank_transfer"

        provider = Payments.provider_for(@payment_method)
        provider.start(
          orders,
          success_url: params[:success_url].presence || "#{request.base_url}/",
          cancel_url: params[:cancel_url].presence || "#{request.base_url}/"
        )
      rescue StandardError
        nil
      end

      def payment_instructions(orders)
        return nil unless @payment_method == "bank_transfer"

        {
          iban: Setting.get("bank_iban"),
          beneficiary: Setting.get("bank_beneficiary"),
          reference: orders.map(&:number).join(", "),
          amount_cents: orders.sum(&:total_cents),
          deadline_days: Setting.get("payment_deadline_days", 3).to_i
        }
      end
    end
  end
end
