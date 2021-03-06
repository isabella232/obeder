FactoryGirl.define do
  factory :user do
    name
    email { generate :email }
    password { generate :string }
    role 'user'
    description
    aasm_state 'active'

    trait :admin do
      role 'admin'
    end

    trait :cook do
      role 'cook'
    end

    trait :with_user_menu_dishes do
      after(:create) do |user|
        create_list :user_menu_with_user_menu_dishes, 3, user: user
      end
    end
  end
end
