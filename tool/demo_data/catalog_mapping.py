"""How each row of the inventory sheet becomes a product + variant in the app.

Each artist has:
  - a default category (rows not listed in `groups` become standalone products)
  - `groups`: source product name -> (product name, {attribute: value}[, category])

Rows with the same product name (per artist) become variants of one product.
Source names are matched after trimming spaces and leading dashes.
"""

STORE_ARTIST = 'Entre Salas'  # rows with artist "?" belong to the store

# ------------------------------------------------------------------ categories
# (name, VAT %, {attribute: fixed options (empty list = free text)})
CATEGORIES = [
    ('Clothing', 21, {'Size': ['XS', 'XS/S', 'S', 'M', 'L', 'XL'], 'Style': []}),
    ('Jewellery', 21, {'Finish': [], 'Style': []}),
    ('Accessories', 21, {'Style': [], 'Size': []}),
    ('Ceramics', 21, {'Design': [], 'Size': []}),
    ('Prints & Posters', 21, {'Design': [], 'Size': ['A4', 'A3', 'Big']}),
    ('Postcards & Stickers', 21, {'Design': []}),
    ('Books & Zines', 4, {'Language': []}),
    ('Stationery', 21, {'Design': []}),
    ('Home & Textiles', 21, {'Pattern': [], 'Size': ['Single', 'Double', 'King']}),
    ('Lamps', 21, {'Design': []}),
    ('Candles', 21, {'Scent': []}),
    ('Toys & Games', 21, {'Design': []}),
    ('Art & Objects', 21, {'Design': []}),
    ('Food & Drink', 0, {'Option': []}),  # café / bar, 0% VAT as instructed
    ('Miscellaneous', 21, {}),
]

# Rows left out of the demo entirely.
EXCLUDE = {
    ('Celina', 'Workshop Fee'),
    ('?', 'Participation Fee'),
}

# Price corrections (VAT included).
PRICE_FIX = {
    ('Natalia', 'Crop Top'): 45.0,
}

# Café items: stock is not really tracked, so they get a large stock.
LARGE_STOCK_CATEGORY = 'Food & Drink'
LARGE_STOCK_FINAL = 300

# Clothing whose quantity is split into sizes to show size variants.
# (artist, product) -> sizes; the sheet quantity is spread across them.
SPLIT_SIZES = {
    ('Every Tomorrow', 'Long Sleeve Shirt'): ['S', 'M', 'L'],
    ('Every Tomorrow', 'T-Shirt'): ['S', 'M', 'L'],
    ('Every Tomorrow', 'Sweatshirt'): ['S', 'M', 'L'],
    ('Lolo', 'Bomber Jacket'): ['S', 'M', 'L'],
    ('Lolo', 'Denim Jacket'): ['S', 'M', 'L'],
    ('Lolo', 'Denim Pants'): ['S', 'M', 'L'],
    ('Lolo', 'Double Layered Shirt'): ['S', 'M', 'L'],
    ('Lolo', 'Hoodie'): ['S', 'M', 'L'],
    ('Pattern Chineso', 'Sleep Top'): ['S', 'M', 'L'],
    ('Elleonor', 'Socks'): ['S', 'M', 'L'],
}

# Je Jewellery and similar: "Name - gold" / "Name (Silver & Blue)" patterns are
# parsed automatically for these artists (see generate_demo_data.py).
AUTO_FINISH_ARTISTS = {'Je Jewellery', 'Leily Khabiri'}

ARTISTS = {
    '?': {
        'category': 'Food & Drink',
        'groups': {
            '2026/27 Calendar': ('2026/27 Calendar', {}, 'Stationery'),
            '25 Abril Poster': ('25 Abril Poster', {}, 'Prints & Posters'),
            'Beer (sin alcohol)': ('Beer (sin alcohol)', {'Option': 'Lager'}),
            'IPA beer (sin alcohol)': ('Beer (sin alcohol)', {'Option': 'IPA'}),
            'Butter Candle': ('Butter Candle', {}, 'Candles'),
            'Pimiento Olives Candle': ('Pimiento Olives Candle', {}, 'Candles'),
            'Ripe Tomato Candle': ('Ripe Tomato Candle', {}, 'Candles'),
            'Café Americano': ('Café', {'Option': 'Americano'}),
            'Café Cortado': ('Café', {'Option': 'Cortado'}),
            'Café Espresso': ('Café', {'Option': 'Espresso'}),
            'Café Flat White': ('Café', {'Option': 'Flat White'}),
            'Café Iced Latte': ('Café', {'Option': 'Iced Latte'}),
            'Café con leche': ('Café', {'Option': 'Con leche'}),
            'Iced Matcha': ('Matcha', {'Option': 'Iced'}),
            'Matcha Latte': ('Matcha', {'Option': 'Latte'}),
            'Peach & Orange Drink - Living Things': ('Living Things Drink', {'Option': 'Peach & Orange'}),
            'Watermelon & Lime drink - Living Things': ('Living Things Drink', {'Option': 'Watermelon & Lime'}),
            'Rosé Wine Bottle': ('Rosé Wine', {'Option': 'Bottle'}),
            'Rosé Wine glass': ('Rosé Wine', {'Option': 'Glass'}),
            'Lesbian t shirt': ('Lesbian T-Shirt', {}, 'Clothing'),
        },
    },
    '2Barba Supportive': {'category': 'Miscellaneous', 'groups': {}},
    'Ajuar': {
        'category': 'Clothing',
        'groups': {
            'Bikini Bottom Supermarket': ('Bikini Bottom', {'Style': 'Supermarket'}),
            'Bikini bottom oyster': ('Bikini Bottom', {'Style': 'Oyster'}),
            'Bikini bottom perro': ('Bikini Bottom', {'Style': 'Perro'}),
            'Bikini bottom pink (M)': ('Bikini Bottom', {'Style': 'Pink', 'Size': 'M'}),
            'Bikini Top Supermarket (S)': ('Bikini Top', {'Style': 'Supermarket', 'Size': 'S'}),
            'Bikini top oyster': ('Bikini Top', {'Style': 'Oyster'}),
            'Bikini top perro': ('Bikini Top', {'Style': 'Perro'}),
            'Bikini top pink (M)': ('Bikini Top', {'Style': 'Pink', 'Size': 'M'}),
            'Bikini Pink full set (M)': ('Bikini Full Set', {'Style': 'Pink', 'Size': 'M'}),
            'Bikini Supermarket full set': ('Bikini Full Set', {'Style': 'Supermarket'}),
            'Bikini oyster full set': ('Bikini Full Set', {'Style': 'Oyster'}),
            'Bikini perro full set': ('Bikini Full Set', {'Style': 'Perro'}),
            'Camiseta Azul': ('Camiseta', {'Style': 'Azul'}),
            'Camiseta Flores': ('Camiseta', {'Style': 'Flores'}),
            'Camiseta Perro': ('Camiseta', {'Style': 'Perro'}),
            'Panties Pimiento': ('Panties', {'Style': 'Pimiento'}),
            'Panties Print': ('Panties', {'Style': 'Print'}),
            'Thong Panties': ('Panties', {'Style': 'Thong'}),
            'T Shirt Gelatina': ('T-Shirt', {'Style': 'Gelatina'}),
            'T Shirt Orange Juice (XS/S)': ('T-Shirt', {'Style': 'Orange Juice', 'Size': 'XS/S'}),
            'T Shirt Sriracha': ('T-Shirt', {'Style': 'Sriracha'}),
        },
    },
    'Ames Dept': {
        'category': 'Clothing',
        'groups': {
            # Listed with a leading "-" in the sheet and priced like the tees.
            'Ames Blues': ('Ames Dept Piece', {'Style': 'Ames Blues'}),
            'Ames Girl': ('Ames Dept Piece', {'Style': 'Ames Girl'}),
            'Ames at Last': ('Ames Dept Piece', {'Style': 'Ames at Last'}),
            'Broken Plates': ('Ames Dept Piece', {'Style': 'Broken Plates'}),
            'Pick your king': ('Ames Dept Piece', {'Style': 'Pick your king'}),
            'Real Stories': ('Ames Dept Piece', {'Style': 'Real Stories'}),
            '<3 CAMO Cap': ('Cap', {'Style': '<3 Camo'}, 'Accessories'),
            '<3 Snow CAMO Cap': ('Cap', {'Style': '<3 Snow Camo'}, 'Accessories'),
            'Im Thinking Cap': ('Cap', {'Style': "I'm Thinking"}, 'Accessories'),
            'Kiss Cap': ('Cap', {'Style': 'Kiss'}, 'Accessories'),
            'Piece Cap': ('Cap', {'Style': 'Piece'}, 'Accessories'),
            'T shirt Barwouf': ('T-Shirt', {'Style': 'Barwouf'}),
            'T shirt Forever': ('T-Shirt', {'Style': 'Forever'}),
            'T shirt Girls': ('T-Shirt', {'Style': 'Girls'}),
            'T shirt TTOTT': ('T-Shirt', {'Style': 'TTOTT'}),
        },
    },
    'Ana Drucker': {
        'category': 'Ceramics',
        'groups': {
            'Algodón Bookend': ('Bookend', {'Design': 'Algodón'}),
            'Bosque Bookend': ('Bookend', {'Design': 'Bosque'}),
            'Hormiguero Candleholder': ('Hormiguero Candleholder', {}),
        },
    },
    'Artifact': {
        'category': 'Home & Textiles',
        'groups': {
            'Lampara asteroide': ('Lámpara', {'Design': 'Asteroide'}, 'Lamps'),
            'Lámpara Hongos mágicos': ('Lámpara', {'Design': 'Hongos mágicos'}, 'Lamps'),
            'Lámpara medusa de compases': ('Lámpara', {'Design': 'Medusa de compases'}, 'Lamps'),
            'Lámpara seta falsa oronja': ('Lámpara', {'Design': 'Seta falsa oronja'}, 'Lamps'),
            'Melted Ring single': ('Melted Ring', {'Style': 'Single'}, 'Jewellery'),
            'Melted Ring double': ('Melted Ring', {'Style': 'Double'}, 'Jewellery'),
            'bedrunner blue lotus (single)': ('Bedrunner', {'Pattern': 'Blue Lotus', 'Size': 'Single'}),
            'bedrunner blue lotus (double)': ('Bedrunner', {'Pattern': 'Blue Lotus', 'Size': 'Double'}),
            'bedrunner blue lotus (king)': ('Bedrunner', {'Pattern': 'Blue Lotus', 'Size': 'King'}),
            'bedrunner red ikat (single)': ('Bedrunner', {'Pattern': 'Red Ikat', 'Size': 'Single'}),
            'bedrunner red ikat (double)': ('Bedrunner', {'Pattern': 'Red Ikat', 'Size': 'Double'}),
            'bedrunner red ikat (king)': ('Bedrunner', {'Pattern': 'Red Ikat', 'Size': 'King'}),
            'cushion funky pharaoh': ('Cushion Funky Pharaoh', {}),
        },
    },
    'BESSO': {
        'category': 'Food & Drink',
        'groups': {
            'Fresa Pasión': ('BESSO Drink', {'Option': 'Fresa Pasión'}),
            'Lima Limón': ('BESSO Drink', {'Option': 'Lima Limón'}),
            'Melocotón & Maracuyá': ('BESSO Drink', {'Option': 'Melocotón & Maracuyá'}),
        },
    },
    'Celina': {
        'category': 'Accessories',
        'groups': {
            'Pin Big': ('Pin', {'Style': 'Big'}),
            'Pin Small': ('Pin', {'Style': 'Small'}),
            'Pin Small with detail': ('Pin', {'Style': 'Small with detail'}),
            'Pin Small with tassle': ('Pin', {'Style': 'Small with tassel'}),
            'Cherry Tomato Candle': ('Cherry Tomato Candle', {}, 'Candles'),
        },
    },
    'Cora': {
        'category': 'Ceramics',
        'groups': {
            'Cross Cultural Chairs - Book': ('Cross Cultural Chairs', {}, 'Books & Zines'),
        },
    },
    'ERAS Bags': {
        'category': 'Accessories',
        'groups': {
            'Ari Bag Black': ('ERAS Bag', {'Style': 'Ari Black'}),
            'Harper Bag Nature': ('ERAS Bag', {'Style': 'Harper Nature'}),
            'Lia Bag Blue': ('ERAS Bag', {'Style': 'Lia Blue'}),
            'Noa Bag Brown': ('ERAS Bag', {'Style': 'Noa Brown'}),
        },
    },
    'Elleonor': {
        'category': 'Accessories',
        'groups': {
            'A3 Print': ('Print', {'Size': 'A3'}, 'Prints & Posters'),
            'A4 Print': ('Print', {'Size': 'A4'}, 'Prints & Posters'),
            'Acero necklaces w/ microplastics': ('Necklace', {'Style': 'Acero w/ microplastics'}, 'Jewellery'),
            'Necklace rope': ('Necklace', {'Style': 'Rope'}, 'Jewellery'),
            'Necklaces': ('Necklace', {'Style': 'Classic'}, 'Jewellery'),
            'Necklaces beads': ('Necklace', {'Style': 'Beads'}, 'Jewellery'),
            'Acero rings microplastics': ('Ring', {'Style': 'Acero microplastics'}, 'Jewellery'),
            'Rings acero and microplastic': ('Ring', {'Style': 'Acero & microplastic'}, 'Jewellery'),
            'Rings resin transparent': ('Ring', {'Style': 'Resin transparent'}, 'Jewellery'),
            'Black & white silver ring': ('Ring', {'Style': 'Black & white silver'}, 'Jewellery'),
            'Earrings': ('Earrings', {'Style': 'Classic'}, 'Jewellery'),
            'Earrings aco micro plastico': ('Earrings', {'Style': 'Acero microplastic'}, 'Jewellery'),
            'Earrings rope': ('Earrings', {'Style': 'Rope'}, 'Jewellery'),
            'Earrings star': ('Earrings', {'Style': 'Star'}, 'Jewellery'),
            'Bellychain': ('Bellychain', {}, 'Jewellery'),
            'Amor Scarf': ('Scarf', {'Style': 'Amor'}),
            'Scarf clouds': ('Scarf', {'Style': 'Clouds'}),
            'scarf colorful check': ('Scarf', {'Style': 'Colorful check'}),
            'scarf doodle mind': ('Scarf', {'Style': 'Doodle mind'}),
            'Amor t-shirt': ('T-Shirt', {'Style': 'Amor'}, 'Clothing'),
            'tired t-shirt': ('T-Shirt', {'Style': 'Tired'}, 'Clothing'),
            'veggie t-shirt': ('T-Shirt', {'Style': 'Veggie'}, 'Clothing'),
            'Tee baby blue': ('T-Shirt', {'Style': 'Baby blue'}, 'Clothing'),
            'Tee black teletubbie': ('T-Shirt', {'Style': 'Black teletubbie'}, 'Clothing'),
            'Tee brown 1993': ('T-Shirt', {'Style': 'Brown 1993'}, 'Clothing'),
            'Tee white nature waits': ('T-Shirt', {'Style': 'White nature waits'}, 'Clothing'),
            'Tee white peace nature waits': ('T-Shirt', {'Style': 'White peace nature waits'}, 'Clothing'),
            'Long sleeve flowers': ('Long Sleeve', {'Style': 'Flowers'}, 'Clothing'),
            'Long sleeves cat': ('Long Sleeve', {'Style': 'Cat'}, 'Clothing'),
            'eyelet long sleeve': ('Long Sleeve', {'Style': 'Eyelet'}, 'Clothing'),
            'white long sleeve': ('Long Sleeve', {'Style': 'White'}, 'Clothing'),
            'Shirts metal holes': ('Shirt Metal Holes', {}, 'Clothing'),
            'socks': ('Socks', {}, 'Clothing'),
            'Cat Cap': ('Cap', {'Style': 'Cat'}),
            'cap': ('Cap', {'Style': 'Classic'}),
            'Hat clouds': ('Hat', {'Style': 'Clouds'}),
            'Hat embroided': ('Hat', {'Style': 'Embroidered'}),
            'Hat love': ('Hat', {'Style': 'Love'}),
            'Touca crochet': ('Hat', {'Style': 'Touca crochet'}),
            'Keycharm acero small with microplasticos': ('Keycharm', {'Style': 'Acero small microplastics'}),
            'Keycharm cat heart': ('Keycharm', {'Style': 'Cat heart'}),
            'Keycharm cat small': ('Keycharm', {'Style': 'Cat small'}),
            'Keycharm flor': ('Keycharm', {'Style': 'Flor'}),
            'Keycharm riscas': ('Keycharm', {'Style': 'Riscas'}),
            'Tote peace': ('Tote Bag', {'Style': 'Peace'}),
            'Tote veggie': ('Tote Bag', {'Style': 'Veggie'}),
            'Original': ('Original Artwork', {}, 'Art & Objects'),
            'Postcards': ('Postcards', {}, 'Postcards & Stickers'),
            'Temporary Tattoos': ('Temporary Tattoos', {}, 'Postcards & Stickers'),
            'birds towel': ('Birds Towel', {}, 'Home & Textiles'),
        },
    },
    'Erica': {
        'category': 'Prints & Posters',
        'groups': {
            'Amistad en la montaña Print': ('Poster', {'Design': 'Amistad en la montaña'}),
            'Blue & White Vase Poster': ('Poster', {'Design': 'Blue & White Vase'}),
            'Frutta di Stagione Poster': ('Poster', {'Design': 'Frutta di Stagione'}),
            'Mo Cow Poster': ('Poster', {'Design': 'Mo Cow'}),
            'Pink Vase Poster': ('Poster', {'Design': 'Pink Vase'}),
            'Tennis Poster': ('Poster', {'Design': 'Tennis'}),
            'Tigre Poster': ('Poster', {'Design': 'Tigre'}),
            'Verdures di Stagione Poster': ('Poster', {'Design': 'Verdures di Stagione'}),
            'Baraja Italiana': ('Baraja Italiana', {}, 'Toys & Games'),
            'Pedro Pedro Zine': ('Pedro Pedro Zine', {}, 'Books & Zines'),
            'Sticker Pack': ('Sticker Pack', {}, 'Postcards & Stickers'),
        },
    },
    'Every Tomorrow': {
        'category': 'Clothing',
        'groups': {
            'Book': ('Every Tomorrow Book', {}, 'Books & Zines'),
            'long sleeve shirt': ('Long Sleeve Shirt', {}),
            'short sleeve t shirt': ('T-Shirt', {}),
            'sweatshirt': ('Sweatshirt', {}),
        },
    },
    'Fayoum': {
        'category': 'Ceramics',
        'groups': {
            'Espresso cup green & white': ('Espresso Cup', {'Design': 'Green & white'}),
            'Espresso cup metallic': ('Espresso Cup', {'Design': 'Metallic'}),
            'Espresso cup metallic & matte': ('Espresso Cup', {'Design': 'Metallic & matte'}),
            'Espresso cup special pink & green pattern': ('Espresso Cup', {'Design': 'Special pink & green'}),
            'cup special blue & white pattern': ('Special Cup', {'Design': 'Blue & white'}),
            'cup special blue pattern': ('Special Cup', {'Design': 'Blue'}),
        },
    },
    'Francispiscapa': {
        'category': 'Ceramics',
        'groups': {
            'Black Mask': ('Mask', {'Design': 'Black'}, 'Art & Objects'),
            'Orange Mask': ('Mask', {'Design': 'Orange'}, 'Art & Objects'),
            'White Mask': ('Mask', {'Design': 'White'}, 'Art & Objects'),
            'Cabeça grande ceramica': ('Cabeça Cerâmica', {'Size': 'Grande'}),
            'Cabeça pequena ceramica': ('Cabeça Cerâmica', {'Size': 'Pequena'}),
            'Green Hill': ('Green Hill', {}, 'Art & Objects'),
        },
    },
    'Je Jewellery': {'category': 'Jewellery', 'groups': {}},  # AUTO_FINISH
    'Jumbo Press': {
        'category': 'Books & Zines',
        'groups': {
            **{name: ('Risograph Poster', {'Design': name.replace('Cheers! (sun & moon)', 'Cheers! (Sun & Moon)')},
                      'Prints & Posters')
               for name in ['Bathroom', 'Big Ears Big Business', 'Cheers! (sun & moon)', 'Crunchie', 'Cuppa',
                            'David Bowie', 'Daydreamers', 'Fuego', 'Grocery People', 'Headspace', 'Love Car', 'Mamo',
                            'New Day', 'Objects', 'Patchwork', 'Pink Car', 'Real Bad Shape', 'Ritmo del Mundo',
                            'Se Comparte', 'Si Te Pierdes', 'Skull Study', 'Snake Eyes', 'Sync', 'Un Cafecito',
                            'Volver a Empezar', 'Were All Going to Die Anyway']},
            'A4 Print': ('A4 Print', {'Size': 'A4'}, 'Prints & Posters'),
            'Always Drawing Sketchbook': ('Always Drawing Sketchbook', {}, 'Stationery'),
            'Comic Sketchbook': ('Comic Sketchbook', {}, 'Stationery'),
            "Don't Stress Daily Planner": ("Don't Stress Daily Planner", {}, 'Stationery'),
            'Meal Plan': ('Meal Plan', {}, 'Stationery'),
            'Risograph Stationery Set': ('Risograph Stationery Set', {}, 'Stationery'),
            'Tape': ('Tape', {}, 'Stationery'),
            'To do list': ('To Do List', {}, 'Stationery'),
            'Stickers - My first alphabet': ('Sticker Pack', {'Design': 'My first alphabet'}, 'Postcards & Stickers'),
            'Stickers - My first numbers': ('Sticker Pack', {'Design': 'My first numbers'}, 'Postcards & Stickers'),
            'Stickers - Vintage Sticker Pack': ('Sticker Pack', {'Design': 'Vintage'}, 'Postcards & Stickers'),
            'Bag': ('Jumbo Press Bag', {}, 'Accessories'),
            'Baraja Española (playing cards)': ('Baraja Española', {}, 'Toys & Games'),
            'Ceramic Vase (Art Palette)': ('Ceramic Vase', {'Design': 'Art Palette'}, 'Ceramics'),
            'Ceramic Vase (Blue drawing)': ('Ceramic Vase', {'Design': 'Blue drawing'}, 'Ceramics'),
            'Ceramic Vase (Fruits)': ('Ceramic Vase', {'Design': 'Fruits'}, 'Ceramics'),
            'Ceramic Vase (Red & Blue)': ('Ceramic Vase', {'Design': 'Red & Blue'}, 'Ceramics'),
            'Ceramic Vase (Snoopy)': ('Ceramic Vase', {'Design': 'Snoopy'}, 'Ceramics'),
            'Ceramic Vase (Stripes)': ('Ceramic Vase', {'Design': 'Stripes'}, 'Ceramics'),
            'Ceramic Vase (White & Purple)': ('Ceramic Vase', {'Design': 'White & Purple'}, 'Ceramics'),
            'Ceramic Vase (Yellow Dog)': ('Ceramic Vase', {'Design': 'Yellow Dog'}, 'Ceramics'),
            'Cushion City Dreamz': ('Cushion City Dreamz', {}, 'Home & Textiles'),
            'ens veiem als encants': ('Ens veiem als encants', {'Language': 'Català'}),
            "l'elefant i el carbassò": ("L'elefant i el carbassò", {'Language': 'Català'}),
            'mini puzzles bird toy': ('Mini Puzzle', {'Design': 'Bird'}, 'Toys & Games'),
            'mini puzzles mouse toy': ('Mini Puzzle', {'Design': 'Mouse'}, 'Toys & Games'),
            'pizcasss bus escola toy': ('Pizcasss Toy', {'Design': 'Bus escola'}, 'Toys & Games'),
            'pizcasss plane toy': ('Pizcasss Toy', {'Design': 'Plane'}, 'Toys & Games'),
            'pizcasss policia toy': ('Pizcasss Toy', {'Design': 'Policía'}, 'Toys & Games'),
            'pizcasss truck toy': ('Pizcasss Toy', {'Design': 'Truck'}, 'Toys & Games'),
            **{src: ('Little Toy', {'Design': label}, 'Toys & Games') for src, label in [
                ('baby boy toy', 'Baby boy'), ('baby toy pink cat', 'Baby pink cat'),
                ('banana with feet toy', 'Banana with feet'), ('dog with hat toy', 'Dog with hat'),
                ('dogs kissing toy', 'Dogs kissing'), ('green car toy', 'Green car'),
                ('green elephant toy', 'Green elephant'), ('orange mousse toy', 'Orange mousse'),
                ('yellow bear toy', 'Yellow bear'), ('yellow rabbit toy', 'Yellow rabbit')]},
        },
    },
    'Le Puzz': {
        'category': 'Toys & Games',
        'groups': {
            'Poker Dogs': ('Le Puzz Puzzle', {'Design': 'Poker Dogs'}),
            'Raisin an Eyebrow': ('Le Puzz Puzzle', {'Design': 'Raisin an Eyebrow'}),
            'lighten up': ('Le Puzz Puzzle', {'Design': 'Lighten Up'}),
        },
    },
    'Leily Khabiri': {'category': 'Jewellery', 'groups': {}},  # AUTO_FINISH
    'Lino': {
        'category': 'Prints & Posters',
        'groups': {
            'Print Leb & Pal': ('Lino Print', {'Design': 'Leb & Pal'}),
            'Print Margerges': ('Lino Print', {'Design': 'Margerges'}),
            'Print Mushroom': ('Lino Print', {'Design': 'Mushroom'}),
        },
    },
    'Livia': {
        'category': 'Art & Objects',
        'groups': {
            'Amulet 01': ('Amulet', {'Design': '01'}),
            'Amulet 03': ('Amulet', {'Design': '03'}),
        },
    },
    'Lolo': {
        'category': 'Clothing',
        'groups': {
            'Blue tshirt': ('T-Shirt', {'Style': 'Blue'}),
            'Pink tshirt': ('T-Shirt', {'Style': 'Pink'}),
            'Denim Jeckets': ('Denim Jacket', {}),
            'Lolo Denim Jacket': ('Denim Jacket', {}),  # same item, typo in the sheet
            'Joggers': ('Joggers', {'Style': 'Classic'}),
            'Velour Joggers': ('Joggers', {'Style': 'Velour'}),
        },
    },
    'Lorena': {
        'category': 'Accessories',
        'groups': {
            'Jarrón Ceramica': ('Jarrón Cerámica', {}, 'Ceramics'),
            'Pin 1 piece': ('Pin', {'Style': '1 piece'}),
            'Pin 2 piece': ('Pin', {'Style': '2 piece'}),
            'Sticker Pack': ('Sticker Pack', {}, 'Postcards & Stickers'),
        },
    },
    'L’herencia': {
        'category': 'Food & Drink',
        'groups': {
            'Wine Bottle': ("L'herencia Wine", {'Option': 'Bottle'}),
            'L’herencia Wine Glass': ("L'herencia Wine", {'Option': 'Glass'}),
        },
    },
    'Maison Barrere': {
        'category': 'Home & Textiles',
        'groups': {
            'Cigarette glass': ('Glass', {'Pattern': 'Cigarette'}),
            'Imparfait glass': ('Glass', {'Pattern': 'Imparfait'}),
            'Pompette glass': ('Glass', {'Pattern': 'Pompette'}),
        },
    },
    'Malarko': {
        'category': 'Ceramics',
        'groups': {
            '1 Min Bong': ('1 Min Bong', {}, 'Miscellaneous'),
            'Bueno Bonito Barato Poster': ('Poster', {'Design': 'Bueno Bonito Barato'}, 'Prints & Posters'),
            'Rebajado Por Cierre Poster': ('Poster', {'Design': 'Rebajado Por Cierre'}, 'Prints & Posters'),
            'Cap': ('Cap', {}, 'Accessories'),
            'Keychain': ('Keychain', {}, 'Accessories'),
            'Pin': ('Pin', {}, 'Accessories'),
            'Big Castle w cup': ('Sculpture with Cup', {'Design': 'Big Castle'}, 'Art & Objects'),
            'Michelin Man w Cup': ('Sculpture with Cup', {'Design': 'Michelin Man'}, 'Art & Objects'),
        },
    },
    'Matilde Cunha': {
        'category': 'Prints & Posters',
        'groups': {
            '2026 Calendar': ('2026 Calendar', {}, 'Stationery'),
            'A4 Print': ('A4 Print', {'Size': 'A4'}),
            'Book': ('Matilde Cunha Book', {}, 'Books & Zines'),
            'Bookmarks': ('Bookmarks', {}, 'Stationery'),
            'Chinese Print on Fabric': ('Print on Fabric', {'Design': 'Chinese'}),
            'print on fabric': ('Print on Fabric', {'Design': 'Classic'}),
            'Mini Sticker Pack': ('Mini Sticker Pack', {}, 'Postcards & Stickers'),
            'Photo Strip': ('Photo Strip', {}, 'Postcards & Stickers'),
            'chair poster big': ('Big Poster', {'Design': 'Chair', 'Size': 'Big'}),
            'view poster big': ('Big Poster', {'Design': 'View', 'Size': 'Big'}),
            'cones postcard': ('Postcard', {'Design': 'Cones'}, 'Postcards & Stickers'),
            'green & white postcard': ('Postcard', {'Design': 'Green & white'}, 'Postcards & Stickers'),
            'mountain postcard': ('Postcard', {'Design': 'Mountain'}, 'Postcards & Stickers'),
            'pool postcard': ('Postcard', {'Design': 'Pool'}, 'Postcards & Stickers'),
        },
    },
    'Midnight Groceries': {
        'category': 'Jewellery',
        'groups': {
            'Delicate Ring': ('Delicate Ring', {'Style': '01'}),
            'Delicate Ring 02': ('Delicate Ring', {'Style': '02'}),
            'Grape Pendant': ('Pendant', {'Style': 'Grape'}),
            'Horse Pendant': ('Pendant', {'Style': 'Horse'}),
        },
    },
    'Natalia': {
        'category': 'Ceramics',
        'groups': {
            'Asian Bird Ceramic': ('Ceramic Figure', {'Design': 'Asian bird'}),
            'Ceramic Cat': ('Ceramic Figure', {'Design': 'Cat'}),
            'Ceramic Frog': ('Ceramic Figure', {'Design': 'Frog'}),
            'Ceramic fish & guy flute': ('Ceramic Figure', {'Design': 'Fish & guy flute'}),
            'Crop Top': ('Crop Top', {}, 'Clothing'),
            'Tote Bag 1': ('Tote Bag', {'Style': '1'}, 'Accessories'),
            'Tote 2': ('Tote Bag', {'Style': '2'}, 'Accessories'),
            'Tote 3': ('Tote Bag', {'Style': '3'}, 'Accessories'),
        },
    },
    'Pajaro': {
        'category': 'Art & Objects',
        'groups': {
            'Azul Beige': ('Pájaro', {'Design': 'Azul Beige'}),
            'Azul El Fruto Rojo': ('Pájaro', {'Design': 'Azul El Fruto Rojo'}),
        },
    },
    'Palistik': {'category': 'Postcards & Stickers', 'groups': {}},
    'Pattern Chineso': {
        'category': 'Clothing',
        'groups': {
            'Botijo Joana': ('Botijo', {'Design': 'Joana'}, 'Ceramics'),
            'Botijo Ria': ('Botijo', {'Design': 'Ria'}, 'Ceramics'),
            'Jarrón Lluc': ('Jarrón Lluc', {}, 'Ceramics'),
            'Mini Cántaro Llum': ('Mini Cántaro Llum', {}, 'Ceramics'),
            'Bucket hat seri flower': ('Bucket Hat Seri Flower', {}, 'Accessories'),
            'Duffle Bag laser doble capa azul': ('Duffle Bag', {'Style': 'Laser doble capa azul'}, 'Accessories'),
            'Duffle Bag seri flower': ('Duffle Bag', {'Style': 'Seri flower'}, 'Accessories'),
            'Camiseta falleros': ('Camiseta', {'Style': 'Falleros'}),
            'Camiseta polka amarillo serig': ('Camiseta', {'Style': 'Polka amarillo serig'}),
            'Hoodie flores plantilla + seri': ('Hoodie', {'Style': 'Flores plantilla + seri'}),
            'Hoodie polka spark': ('Hoodie', {'Style': 'Polka spark'}),
            'Mariscal hoodie perro': ('Mariscal', {'Style': 'Hoodie perro'}),
            'Mariscal polka naranja': ('Mariscal', {'Style': 'Polka naranja'}),
            'Sleep - Short Sleeve': ('Sleep Top', {'Style': 'Short sleeve'}),
            'Sleep Long Sleeve': ('Sleep Top', {'Style': 'Long sleeve'}),
        },
    },
    'Paula Grenouille': {
        'category': 'Ceramics',
        'groups': {
            'Poster': ('Poster', {}, 'Prints & Posters'),
            'Scarf Brown': ('Scarf', {'Style': 'Brown'}, 'Accessories'),
            'Scarf Pink': ('Scarf', {'Style': 'Pink'}, 'Accessories'),
            'boxers black': ('Boxers', {'Style': 'Black'}, 'Clothing'),
            'boxers white': ('Boxers', {'Style': 'White'}, 'Clothing'),
            'clown plato': ('Plato', {'Design': 'Clown'}),
            'girl with braids plato': ('Plato', {'Design': 'Girl with braids'}),
            'kiss plato': ('Plato', {'Design': 'Kiss'}),
            'lines and dots plato': ('Plato', {'Design': 'Lines and dots'}),
            'spider plato': ('Plato', {'Design': 'Spider'}),
            'unicorn pin': ('Unicorn Pin', {}, 'Accessories'),
        },
    },
    'Pisca Francisca': {
        'category': 'Ceramics',
        'groups': {
            'Beige Cup': ('Cup', {'Design': 'Beige'}),
            'Curvy Cup': ('Cup', {'Design': 'Curvy'}),
            'Grey Mug': ('Cup', {'Design': 'Grey mug'}),
            'Big Candleholder': ('Candleholder', {'Design': 'Big'}),
            'Wall Candleholder': ('Candleholder', {'Design': 'Wall'}),
        },
    },
    'RizoMasr': {
        'category': 'Books & Zines',
        'groups': {
            'Fenik Poster': ('RizoMasr Poster', {'Design': 'Fenik'}, 'Prints & Posters'),
            'Halawet Zaman Poster': ('RizoMasr Poster', {'Design': 'Halawet Zaman'}, 'Prints & Posters'),
            'Poster 40Mustaqel ACW2023': ('RizoMasr Poster', {'Design': '40Mustaqel ACW2023'}, 'Prints & Posters'),
            'Kol Sana Postcard': ('Postcard', {'Design': 'Kol Sana'}, 'Postcards & Stickers'),
            'Mango Postcard': ('Postcard', {'Design': 'Mango'}, 'Postcards & Stickers'),
            'Orange Postcard': ('Postcard', {'Design': 'Orange'}, 'Postcards & Stickers'),
            'Strawberry Postcard': ('Postcard', {'Design': 'Strawberry'}, 'Postcards & Stickers'),
            'Watermelon Postcard': ('Postcard', {'Design': 'Watermelon'}, 'Postcards & Stickers'),
            'Games Cube': ('Games Cube', {}, 'Toys & Games'),
        },
    },
    'Tami': {'category': 'Art & Objects', 'groups': {}},
    'Tiago Magelo': {
        'category': 'Prints & Posters',
        'groups': {
            'Coffee Lover': ('Coffee Print', {'Design': 'Coffee Lover'}),
            'Coffee Person': ('Coffee Print', {'Design': 'Coffee Person'}),
            'More Coffee': ('Coffee Print', {'Design': 'More Coffee'}),
            'Stickers': ('Stickers', {}, 'Postcards & Stickers'),
        },
    },
    'Wato': {
        'category': 'Accessories',
        'groups': {
            'bag big': ('Wato Bag', {'Size': 'Big'}),
            'bag small': ('Wato Bag', {'Size': 'Small'}),
        },
    },
    'Yo Te Vi A Ti': {'category': 'Postcards & Stickers', 'groups': {}},
    'Zakaria': {
        'category': 'Jewellery',
        'groups': {
            'Jabbar Figurine': ('Jabbar Figurine', {}, 'Art & Objects'),
            'Man Iltaja Gold Ring': ('Man Iltaja Ring', {'Finish': 'Gold'}),
            'Man Iltaja Silver Ring': ('Man Iltaja Ring', {'Finish': 'Silver'}),
            'Nour Ala Nour Gold Ring': ('Nour Ala Nour Ring', {'Finish': 'Gold'}),
        },
    },
}

# Placeholder artist details, varied on purpose to exercise every feature:
# genders (incl. unset), Spain residency on/off, custom commissions.
# Billing details are obviously fake.
ARTIST_PROFILES = {
    'Entre Salas': dict(gender=None, resident=False, commission=100),  # store-owned: store keeps everything
    '2Barba Supportive': dict(gender='Male', resident=True),
    'Ajuar': dict(gender='Female', resident=True),
    'Ames Dept': dict(gender='Male', resident=False, commission=30),
    'Ana Drucker': dict(gender='Female', resident=True),
    'Artifact': dict(gender='Queer', resident=True, commission=40),
    'BESSO': dict(gender=None, resident=True, commission=25),
    'Celina': dict(gender='Female', resident=True),
    'Cora': dict(gender='Female', resident=False),
    'ERAS Bags': dict(gender='Female', resident=True),
    'Elleonor': dict(gender='Female', resident=False),
    'Erica': dict(gender='Female', resident=False),
    'Every Tomorrow': dict(gender='Queer', resident=True),
    'Fayoum': dict(gender='Male', resident=False, commission=30),
    'Francispiscapa': dict(gender='Male', resident=True),
    'Je Jewellery': dict(gender='Female', resident=True, commission=40),
    'Jumbo Press': dict(gender='Male', resident=True),
    'Le Puzz': dict(gender=None, resident=False),
    'Leily Khabiri': dict(gender='Female', resident=True),
    'Lino': dict(gender='Queer', resident=True),
    'Livia': dict(gender='Female', resident=False),
    'Lolo': dict(gender='Male', resident=True),
    'Lorena': dict(gender='Female', resident=True),
    'L’herencia': dict(gender=None, resident=True, commission=25),
    'Maison Barrere': dict(gender='Male', resident=False),
    'Malarko': dict(gender='Male', resident=True),
    'Matilde Cunha': dict(gender='Female', resident=False),
    'Midnight Groceries': dict(gender='Queer', resident=False),
    'Natalia': dict(gender='Female', resident=True),
    'Pajaro': dict(gender='Male', resident=True),
    'Palistik': dict(gender='Queer', resident=True),
    'Pattern Chineso': dict(gender='Male', resident=True, commission=30),
    'Paula Grenouille': dict(gender='Female', resident=True),
    'Pisca Francisca': dict(gender='Female', resident=True),
    'RizoMasr': dict(gender='Male', resident=False),
    'Tami': dict(gender='Queer', resident=False),
    'Tiago Magelo': dict(gender='Male', resident=False),
    'Wato': dict(gender='Female', resident=True),
    'Yo Te Vi A Ti': dict(gender=None, resident=True),
    'Zakaria': dict(gender='Male', resident=False),
}
