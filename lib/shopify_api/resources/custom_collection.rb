module ShopifyAPI
  class CustomCollection < Base
    include Events
    include Metafields

    # Algorithm to return products in the order driven by the collects
    # 1. Get all the collects for a collection, store them in a hash, so now we have the 3 key details of sort order, collect_id, product_id and position
    # 2. Get all the products for a collection, and for each product found, place it in an ordering based on it's position
    # 3. Return the sorted products for use in the App
    def sorted_products
      products = []
      collects = {}
      page = 1
      count = Collect.count(collection_id: self.id)
      return unless count > 0
      page += count.divmod(250).first
      while page > 0
        list = Collect.all(params: { collection_id: self.id, page: page })
        collects.merge! list.inject({}) { |result, el| result[el.product_id] = { collect_id: el.id, position: el.position }; result }
        page -= 1
      end
      #puts "\ncollects: #{collects.inspect}\n"
      page = 1
      count = Product.count
      return unless count > 0
      page += count.divmod(250).first
      status = {
        fields: 'id,title,handle,variants,images',
        limit: 250,
        collection_id: self.id
      }
      while page > 0
        status[:page] = page
        list = Product.all(params: status)
        # Now we do our trickery and add a position to each element so that sorting becomes easy.
        list.each do |product|
          product.tap { |p| p.position = collects[product.id][:position]; p.collect_id = collects[product.id][:collect_id] }
        end
        products += list
        page -= 1
      end
      products.sort_by(&:position)
    end


    def products
      Product.find(:all, :params => {:collection_id => self.id})
    end
    
    def add_product(product)
      Collect.create(:collection_id => self.id, :product_id => product.id)
    end
    
    def remove_product(product)
      collect = Collect.find(:first, :params => {:collection_id => self.id, :product_id => product.id})
      collect.destroy if collect
    end
  end                                                                 
end
