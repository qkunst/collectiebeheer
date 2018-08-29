module BaseController
  extend ActiveSupport::Concern

  included do
    before_action :authentication_callbacks
    before_action :set_collection
    before_action :set_named_variable_by_class, only: [:show, :edit, :update, :destroy]

    def index
      if @collection
        self.named_collection_variable= controlled_class.where(collection_id: @collection.id).all
      else
        self.named_collection_variable= controlled_class.all
      end
    end

    def show
    end

    def new
      self.named_variable= controlled_class.new
    end

    def create
      self.named_variable = controlled_class.new(white_listed_params)
      named_variable.collection = @collection if @collection
      if named_variable.save
        redirect_to named_collection_url, notice: "#{I18n.t(singularized_name, scope: [:activerecord, :models])} is gemaakt"
      else
        render :new
      end
    end

    def update
      if named_variable.update(white_listed_params)
        redirect_to named_collection_url, notice: "#{I18n.t(singularized_name, scope: [:activerecord, :models])} is bijgewerkt."
      else
        render :edit
      end
    end


    # GET /themes/1/edit
    def edit
    end

    def destroy
      named_variable.destroy
      redirect_to named_collection_url, notice: "#{I18n.t(singularized_name, scope: [:activerecord, :models])} is verwijderd."
    end

    private

    def authentication_callbacks
      authenticate_admin_user!
    end

    def named_collection_url
      @collection ? send("collection_#{controlled_class.table_name}_url", @collection) : send("#{controlled_class.table_name}_url")
    end

    def singularized_name
      controlled_class.table_name.singularize
    end

    def named_collection_variable= values
      instance_variable_set("@#{controlled_class.table_name}", values)
    end
    def named_variable= value
      instance_variable_set("@#{singularized_name}", value)
    end
    def named_variable
      instance_variable_get("@#{singularized_name}")
    end

    def set_named_variable_by_class
      self.named_variable= controlled_class.find(params[:id])
    end

    def white_listed_params
      params.require(singularized_name.to_sym).permit(:name, :description, :order, :hide, :collection_id)
    end
  end
end