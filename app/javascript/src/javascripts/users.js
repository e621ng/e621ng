let User = {};

User.initialize_tabs = function() {
    const container = $(".user-content");

    let selectedTab = "0";
    container.find("h2.tab").on("click", (event) => {
        event.preventDefault();
        
        let element = $(event.target);
        if(element.is("a")) element = element.parents("h2.tab");
        const newTab = element.attr("tab");
        if(newTab == selectedTab) return;

        container.find(`h2[tab="${selectedTab}"]`).removeClass("active");
        container.find(`div.tab-posts[tab="${selectedTab}"]`).addClass("hidden");

        container.find(`h2[tab="${newTab}"]`).addClass("active");
        container.find(`div.tab-posts[tab="${newTab}"]`).removeClass("hidden");
        container.attr("tab-active", newTab);

        selectedTab = newTab;
    });
}

$(() => {
    User.initialize_tabs();
});

export default User;